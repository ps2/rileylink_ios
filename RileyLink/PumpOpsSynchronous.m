//
//  PumpOpsSynchronous.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PumpOpsSynchronous.h"
#import "NSData+Conversion.h"
#import "SendPacketCmd.h"
#import "SendAndListenCmd.h"
#import "MinimedPacket.h"
#import "MessageBase.h"
#import "UpdateRegisterCmd.h"

#define STANDARD_PUMP_RESPONSE_WINDOW 180
#define EXPECTED_MAX_BLE_LATENCY_MS 1500


@implementation PumpOpsSynchronous

- (nonnull instancetype)initWithPump:(nonnull PumpState *)a_pump andSession:(nonnull RileyLinkCmdSession *)a_session {
  
  self = [super init];
  if (self) {
    _session = a_session;
    _pump = a_pump;
  }
  return self;

}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (MessageBase *)msgType:(unsigned char)t withArgs:(NSString *)args {
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x%@", PacketTypeCarelink, _pump.pumpId, t, args];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (MessageBase *)powerMessage
{
  return [self powerMessageWithArgs:@"00"];
}

- (MessageBase *)powerMessageWithArgs:(NSString *)args
{
  return [self msgType:MESSAGE_TYPE_POWER withArgs:args];
}

- (MessageBase *)buttonPressMessage
{
  return [self buttonPressMessageWithArgs:@"00"];
}

- (MessageBase *)buttonPressMessageWithArgs:(NSString *)args
{
  return [self msgType:MESSAGE_TYPE_BUTTON_PRESS withArgs:args];
}

- (MessageBase *)batteryStatusMessage
{
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pump.pumpId, MESSAGE_TYPE_GET_BATTERY];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}


- (MinimedPacket*) sendAndListen:(NSData*)msg
                       timeoutMS:(uint16_t)timeoutMS
                          repeat:(uint8_t)repeat
                msBetweenPackets:(uint8_t)msBetweenPackets
                      retryCount:(uint8_t)retryCount {
  SendAndListenCmd *cmd = [[SendAndListenCmd alloc] init];
  cmd.packet = [MinimedPacket encodeData:msg];
  cmd.timeoutMS = timeoutMS;
  cmd.repeatCount = repeat;
  cmd.msBetweenPackets = msBetweenPackets;
  cmd.retryCount = retryCount;
  cmd.listenChannel = 0;
  MinimedPacket *rxPacket = nil;
  NSInteger totalTimeout = repeat * msBetweenPackets + timeoutMS + EXPECTED_MAX_BLE_LATENCY_MS;
  NSData *response = [_session doCmd:cmd withTimeoutMs:totalTimeout];
  if (response && response.length > 2) {
    rxPacket = [[MinimedPacket alloc] initWithData:response];
  }
  return rxPacket;
}

- (MinimedPacket*) sendAndListen:(NSData*)msg {
  return [self sendAndListen:msg
                   timeoutMS:STANDARD_PUMP_RESPONSE_WINDOW
                      repeat:0
            msBetweenPackets:0
                  retryCount:3];
}

- (BOOL) wakeIfNeeded {
  return [self wakeup:1];
}

- (void) pressButton {
  
  if ([self wakeIfNeeded]) {
    
    MinimedPacket *response = [self sendAndListen:[[self buttonPressMessage] data]];
    
    if (response && response.messageType == MESSAGE_TYPE_ACK) {
      NSLog(@"Pump acknowledged button press (no args)!");
    } else {
      NSLog(@"Pump did not acknowledge button press (no args)");
      return;
    }
    
    NSString *args = @"0104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    
    response = [self sendAndListen:[[self buttonPressMessageWithArgs:args] data]];
    
    if (response && response.messageType == MESSAGE_TYPE_ACK) {
      NSLog(@"Pump acknowledged button press (with args)!");
    } else {
      NSLog(@"Pump did not acknowledge button press (with args)");
      return;
    }
    
  }
}

- (MessageBase *)modelQueryMessage
{
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pump.pumpId, MESSAGE_TYPE_GET_PUMP_MODEL];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (NSString*) getPumpModel {
  if ([self wakeIfNeeded]) {
    MinimedPacket *response = [self sendAndListen:[[self modelQueryMessage] data]];
    
    NSLog(@"*********** getPumpModel: %@", [response hexadecimalString]);
    
    if (response && response.messageType == MESSAGE_TYPE_GET_PUMP_MODEL) {
      return [NSString stringWithCString:&[response.data bytes][7]
                                encoding:NSASCIIStringEncoding];
    }
  }
  return nil;
}

- (NSDictionary*) getBatteryVoltage {
  
  NSString *rvalStatus = @"Unknown";
  float rvalValue = 0.0;
  
  if ([self wakeIfNeeded]) {
    
    MinimedPacket *response = [self sendAndListen:[[self batteryStatusMessage] data]];
    
    if (response && response.valid && response.messageType == MESSAGE_TYPE_GET_BATTERY) {
      unsigned char *data = (unsigned char *)[response.data bytes] + 6;
      
      NSInteger volts = (((int)data[1]) << 8) + data[2];
      rvalStatus = data[0] ? @"Low" : @"Normal";
      rvalValue = volts/100.0;
    }
  }
  
  return @{@"status": rvalStatus, @"value": @(rvalValue)};
}

- (NSData*)parseFramesIntoHistoryPage:(NSArray*)packets {
  NSMutableData *data = [NSMutableData data];
  
  NSRange r = NSMakeRange(6, 64);
  for (NSData *frame in packets) {
    if (frame.length < 70) {
      NSLog(@"Bad frame length in history: %@", [frame hexadecimalString]);
      return nil;
    }
    [data appendData:[frame subdataWithRange:r]];
  }
  return data;
}


- (NSDictionary*) scanForPump {
  
  
  NSMutableArray *scanResults = [NSMutableArray array];
  NSMutableArray *rssi = [NSMutableArray array];
  NSArray *frequencies = @[@916.55, @916.60, @916.65, @916.70, @916.75, @916.80];
  
  [self wakeIfNeeded];
  NSInteger totalSuccesses = 0;
  
  for (NSNumber *freq in frequencies) {
    [self setBaseFrequency:[freq floatValue]];
    NSInteger successCount = 0;
    int avgRSSI = 0;
    int tries = 3;
    for (int i=0; i<tries; i++) {
      MinimedPacket *response = [self sendAndListen:[[self modelQueryMessage] data]];
      if (response && response.valid && response.messageType == MESSAGE_TYPE_GET_PUMP_MODEL) {
        avgRSSI += response.rssi;
        successCount++;
        totalSuccesses++;
      } else {
        avgRSSI += -99;
      }
    }
    avgRSSI = avgRSSI / ((float)tries);
    [scanResults addObject:@(successCount)];
    [rssi addObject:@(avgRSSI)];
  }
  int bestResult = -99, bestIndex = 0;
  for (int i=0; i<rssi.count; i++) {
    NSNumber *result = rssi[i];
    if ([result intValue] > bestResult) {
      bestResult = [result intValue];
      bestIndex = i;
    }
  }
  NSMutableDictionary *rval = [NSMutableDictionary dictionary];
  rval[@"frequencies"] = frequencies;
  rval[@"scanResults"] = scanResults;
  rval[@"avgRSSI"] = rssi;
  
  if (totalSuccesses > 0) {
    rval[@"bestFreq"] = frequencies[bestIndex];
    NSLog(@"Scanning found best results at %@MHz (RSSI: %@)", frequencies[bestIndex], rssi[bestIndex]);
  } else {
    rval[@"error"] = @"Pump did not respond on any of the attempted frequencies.";
  }
  [self setBaseFrequency:[frequencies[bestIndex] floatValue]];
  
  NSLog(@"Frequency scan results: %@", rval);

  return rval;
}

- (BOOL) wakeup:(uint8_t) durationMinutes {
  
  if ([_pump isAwake]) {
    return YES;
  }
  
  MinimedPacket *response = [self sendAndListen:[[self powerMessage] data]
                                      timeoutMS:15000
                                         repeat:200
                               msBetweenPackets:0
                                     retryCount:0];
  
  if (response && response.messageType == MESSAGE_TYPE_ACK) {
    NSLog(@"Pump acknowledged wakeup!");
  } else {
    return NO;
  }
  
  NSString *msg = [NSString stringWithFormat:@"0201%02x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", durationMinutes];
  
  response = [self sendAndListen:[[self powerMessageWithArgs:msg] data]
                       timeoutMS:STANDARD_PUMP_RESPONSE_WINDOW
                          repeat:0
                msBetweenPackets:0
                      retryCount:3];
  
  
  if (response && response.messageType == MESSAGE_TYPE_ACK) {
    NSLog(@"Power on for %d minutes", durationMinutes);
    _pump.awakeUntil = [NSDate dateWithTimeIntervalSinceNow:durationMinutes*60];
  } else {
    return NO;
  }
  return YES;
}

- (void)updateRegister:(uint8_t)addr toValue:(uint8_t)value {
  UpdateRegisterCmd *cmd = [[UpdateRegisterCmd alloc] init];
  cmd.addr = addr;
  cmd.value = value;
  [_session doCmd:cmd withTimeoutMs:EXPECTED_MAX_BLE_LATENCY_MS];
}

- (void)setBaseFrequency:(float)freqMhz {
  uint32_t val = (freqMhz * 1000000)/(RILEYLINK_FREQ_XTAL/pow(2.0,16.0));
  
  [self updateRegister:CC111X_REG_FREQ0 toValue:val & 0xff];
  [self updateRegister:CC111X_REG_FREQ1 toValue:(val >> 8) & 0xff];
  [self updateRegister:CC111X_REG_FREQ2 toValue:(val >> 16) & 0xff];
  NSLog(@"Set frequency to %f", freqMhz);
}

- (NSDictionary*) getHistoryPage:(uint8_t)pageNum {
  float rssiSum = 0;
  int rssiCount = 0;
  
  NSMutableDictionary *responseDict = [NSMutableDictionary dictionary];
  NSMutableArray *responses = [NSMutableArray array];
  
  [self wakeIfNeeded];
  
  NSString *pumpModel = [self getPumpModel];
  
  if (!pumpModel) {
    NSDictionary *tuneResults = [self scanForPump];
    if (tuneResults[@"error"]) {
      responseDict[@"error"] = @"Could not find pump, even after scanning.";
    }
    // Try again to get pump model, after scanning/tuning
    pumpModel = [self getPumpModel];
  }
  
  if (!pumpModel) {
    responseDict[@"error"] = @"get model failed";
    return responseDict;
  } else {
    responseDict[@"pumpModel"] = pumpModel;
  }

  MinimedPacket *response;
  response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"00"] data]];
  
  if (response && response.isValid && response.messageType == MESSAGE_TYPE_ACK) {
    rssiSum += response.rssi;
    rssiCount += 1;
    NSLog(@"Pump acked dump msg (0x80)")
  } else {
    NSLog(@"Missing response to initial read history command");
    responseDict[@"error"] = @"Missing response to initial read history command";
    return responseDict;
  }
  
  NSString *dumpHistArgs = [NSString stringWithFormat:@"01%02x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", pageNum];
  
  response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:dumpHistArgs] data]];
  
  if (response && response.isValid && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
    rssiSum += response.rssi;
    rssiCount += 1;
    [responses addObject:response.data];
  } else {
    NSLog(@"Read history with args command failed");
    responseDict[@"error"] = @"Read history with args command failed";
    return responseDict;
  }
  
  // Send 15 acks, and expect 15 more dumps
  for (int i=0; i<15; i++) {
    
    response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"] data]];
    
    if (response && response.isValid && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
      rssiSum += response.rssi;
      rssiCount += 1;
      [responses addObject:response.data];
    } else {
      NSLog(@"Read history segment %d with args command failed", i);
      responseDict[@"error"] = @"Read history with args command failed";
      return responseDict;
    }
    responseDict[@"pageData"] = [self parseFramesIntoHistoryPage:responses];
  }
  
  if (rssiCount > 0) {
    responseDict[@"avgRSSI"] = @((int)(rssiSum / rssiCount));
  }
  
  // Last ack packet doesn't need a response
  SendPacketCmd *cmd = [[SendPacketCmd alloc] init];
  cmd.packet = [MinimedPacket encodeData:[[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"] data]];
  [_session doCmd:cmd withTimeoutMs:EXPECTED_MAX_BLE_LATENCY_MS];
  return responseDict;
}

@end
