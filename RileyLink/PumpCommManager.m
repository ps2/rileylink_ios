//
//  PumpCommManager.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/6/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpCommManager.h"
#import "NSData+Conversion.h"
#import "SendPacketCmd.h"
#import "SendAndListenCmd.h"
#import "RileyLinkBLEDevice.h"
#import "MinimedPacket.h"
#import "MessageBase.h"

#define STANDARD_PUMP_RESPONSE_WINDOW 180
#define EXPECTED_MAX_BLE_LATENCY_MS 1500

@interface PumpCommManager () {
  NSDate *awakeUntil;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;

@end

@implementation PumpCommManager

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)a_pumpId andDevice:(nonnull RileyLinkBLEDevice *)a_device {
  self = [super init];
  if (self) {
    _pumpId = a_pumpId;
    _device = a_device;
    
    self.pumpCommQueue = [NSOperationQueue mainQueue];
  }
  return self;

}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (MessageBase *)msgType:(unsigned char)t withArgs:(NSString *)args {
    NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x%@", PacketTypeCarelink, _pumpId, t, args];
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
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pumpId, MESSAGE_TYPE_GET_BATTERY];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}


- (MinimedPacket*) sendAndListen:(NSData*)msg
                       timeoutMS:(uint16_t)timeoutMS
                          repeat:(uint8_t)repeat
                msBetweenPackets:(uint8_t)msBetweenPackets
                      retryCount:(uint8_t)retryCount
                     withSession:(RileyLinkCmdSession*)session {
  SendAndListenCmd *cmd = [[SendAndListenCmd alloc] init];
  cmd.packet = [MinimedPacket encodeData:msg];
  cmd.timeoutMS = timeoutMS;
  cmd.repeatCount = repeat;
  cmd.msBetweenPackets = msBetweenPackets;
  cmd.retryCount = retryCount;
  cmd.listenChannel = 2;
  MinimedPacket *rxPacket = nil;
  NSInteger totalTimeout = repeat * msBetweenPackets + timeoutMS + EXPECTED_MAX_BLE_LATENCY_MS;
  NSData *response = [session doCmd:cmd withTimeoutMs:totalTimeout];
  if (response && response.length > 2) {
    rxPacket = [[MinimedPacket alloc] initWithData:response];
  }
  return rxPacket;
}

- (MinimedPacket*) sendAndListen:(NSData*)msg withSession:(RileyLinkCmdSession*)session {
  return [self sendAndListen:msg
                   timeoutMS:STANDARD_PUMP_RESPONSE_WINDOW
                      repeat:0
            msBetweenPackets:0
                  retryCount:3
                 withSession:session];
}


- (void)wakeup:(uint8_t)durationMinutes {
  
}

- (BOOL) isAwake {
  return (awakeUntil != nil && [awakeUntil timeIntervalSinceNow] > 0);
}

- (void) wakeIfNeeded {
  [self wakeup:1];
}

- (void) getHistoryPage {
  // TODO
}

- (void) pressButton {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull s) {
    
    if ([self doWakeup:3 withSession:s]) {
      
      MinimedPacket *response = [self sendAndListen:[[self buttonPressMessage] data]
                                         withSession:s];

      if (response && response.messageType == MESSAGE_TYPE_ACK) {
        NSLog(@"Pump acknowledged button press (no args)!");
      } else {
        NSLog(@"Pump did not acknowledge button press (no args)");
        return;
      }
      
      NSString *args = @"0104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
      
      response = [self sendAndListen:[[self buttonPressMessageWithArgs:args] data]
                          withSession:s];
      
      if (response && response.messageType == MESSAGE_TYPE_ACK) {
        NSLog(@"Pump acknowledged button press (with args)!");
      } else {
        NSLog(@"Pump did not acknowledge button press (with args)");
        return;
      }

    }
  }];

}

- (MessageBase *)modelQueryMessage
{
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pumpId, MESSAGE_TYPE_GET_PUMP_MODEL];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (void) getPumpModel:(void (^ _Nullable)(NSString*))completionHandler {
  
  [_device runSession:^(RileyLinkCmdSession * _Nonnull s) {
    
    NSString *rval = nil;
    
    if ([self doWakeup:3 withSession:s]) {
    
      MinimedPacket *response = [self sendAndListen:[[self modelQueryMessage] data]
                                        withSession:s];
      
      if (response && response.messageType == MESSAGE_TYPE_GET_PUMP_MODEL) {
        rval = [NSString stringWithCString:&[response.data bytes][7]
                                  encoding:NSASCIIStringEncoding];
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(rval);
    });
  }];
}

- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler {
  
  [_device runSession:^(RileyLinkCmdSession * _Nonnull s) {
    
    NSString *rvalStatus = @"Unknown";
    float rvalValue = 0.0;
    
    if ([self doWakeup:3 withSession:s]) {
      
      MinimedPacket *response = [self sendAndListen:[[self batteryStatusMessage] data]
                                         withSession:s];
      
      if (response && response.valid && response.messageType == MESSAGE_TYPE_GET_BATTERY) {
        unsigned char *data = (unsigned char *)[response.data bytes] + 6;
        
        NSInteger volts = (((int)data[1]) << 8) + data[2];
        rvalStatus = data[0] ? @"Low" : @"Normal";
        rvalValue = volts/100.0;
      }
    }
   
    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(rvalStatus, rvalValue);
    });
  }];
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


- (BOOL) doWakeup:(uint8_t) durationMinutes withSession:(RileyLinkCmdSession*)s {
  
  if ([self isAwake]) {
    return YES;
  }
  
  MinimedPacket *response = [self sendAndListen:[[self powerMessage] data]
                                      timeoutMS:15000
                                         repeat:200
                               msBetweenPackets:0
                                     retryCount:0
                                     withSession:s];
  
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
                      retryCount:3
                      withSession:s];

  
  if (response && response.messageType == MESSAGE_TYPE_ACK) {
    NSLog(@"Power on for %d minutes", durationMinutes);
    awakeUntil = [NSDate dateWithTimeIntervalSinceNow:durationMinutes*60];
  } else {
    return NO;
  }
  return YES;
}


- (NSDictionary*) doHistoryPageDump:(uint8_t)pageNum withSession:(RileyLinkCmdSession*)s {
  
  NSMutableDictionary *responseDict = [NSMutableDictionary dictionary];
  NSMutableArray *responses = [NSMutableArray array];
  
  if (![self doWakeup:3 withSession:s]) {
    responseDict[@"error"] = @"Unable to wake pump";
    return responseDict;
  }
  
  MinimedPacket *response;
  response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"00"] data]
                      withSession:s];

  if (response && response.isValid && response.messageType == MESSAGE_TYPE_ACK) {
    NSLog(@"Pump acked dump msg (0x80)")
  } else {
    NSLog(@"Missing response to initial read history command");
    responseDict[@"error"] = @"Missing response to initial read history command";
    return responseDict;
  }

    
  NSString *dumpHistArgs = [NSString stringWithFormat:@"01%02x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", pageNum];

  response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:dumpHistArgs] data]
                      withSession:s];

  if (response && response.isValid && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
    [responses addObject:response.data];
  } else {
    NSLog(@"Read history with args command failed");
    responseDict[@"error"] = @"Read history with args command failed";
    return responseDict;
  }
  
  // Send 15 acks, and expect 15 more dumps
  for (int i=0; i<15; i++) {
    
    response = [self sendAndListen:[[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"] data]
                        withSession:s];
    
    if (response && response.isValid && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
      [responses addObject:response.data];
    } else {
      NSLog(@"Read history segment %d with args command failed", i);
      responseDict[@"error"] = @"Read history with args command failed";
      return responseDict;
    }
    responseDict[@"pageData"] = [self parseFramesIntoHistoryPage:responses];
  }
  
  // Last ack packet doesn't need a response
  SendPacketCmd *cmd = [[SendPacketCmd alloc] init];
  cmd.packet = [MinimedPacket encodeData:[[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"] data]];
  [s doCmd:cmd withTimeoutMs:EXPECTED_MAX_BLE_LATENCY_MS];
  return responseDict;
}


- (void) dumpHistoryPage:(uint8_t)pageNum completionHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull s) {
    NSDictionary *results = [self doHistoryPageDump:pageNum withSession:s];
    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(results);
    });
  }];
}

@end
