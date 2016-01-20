//
//  RileyLinkBLE.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "MinimedPacket.h"
#import "RileyLinkBLEDevice.h"
#import "RileyLinkBLEManager.h"
#import "NSData+Conversion.h"
#import "SendAndListenCmd.h"
#import "GetPacketCmd.h"


@interface __CmdInvocation: NSObject
@property (nonatomic, nonnull, strong) CmdBase *cmd;
@property (nonatomic, nullable, copy) void (^completionHandler)(CmdBase *cmd);
@end

@implementation __CmdInvocation
@end


@interface RileyLinkBLEDevice () <CBPeripheralDelegate> {
  CBCharacteristic *dataCharacteristic;
  CBCharacteristic *responseCountCharacteristic;
  CBCharacteristic *customNameCharacteristic;
  NSMutableArray *incomingPackets;
  NSMutableArray *commands;
  __CmdInvocation *currentInvocation;
  NSMutableData *inBuf;
  NSData *endOfResponseMarker;
  BOOL idleListeningEnabled;
  uint8_t idleListenChannel;
}

@property (nonatomic, nonnull, retain) CBPeripheral * peripheral;

@end


@implementation RileyLinkBLEDevice

@synthesize peripheral = _peripheral;

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral
{
  self = [super init];
  if (self) {
    incomingPackets = [NSMutableArray array];
    commands = [NSMutableArray array];
    
    inBuf = [NSMutableData data];
    endOfResponseMarker = [NSData dataWithHexadecimalString:@"00"];
    
    _peripheral = peripheral;
    _peripheral.delegate = self;
    
    for (CBService *service in _peripheral.services) {
      [self setCharacteristicsFromService:service];
    }
  }
  return self;
}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (NSString *)name
{
  return self.peripheral.name;
}

- (NSString *)peripheralId
{
  return self.peripheral.identifier.UUIDString;
}

- (NSArray*) packets {
  return [NSArray arrayWithArray:incomingPackets];
}

- (void) doCmd:(nonnull CmdBase*)cmd withCompletionHandler:(void (^ _Nullable)(CmdBase * _Nonnull cmd))completionHandler {
  __CmdInvocation *inv = [[__CmdInvocation alloc] init];
  inv.cmd = cmd;
  inv.completionHandler = completionHandler;
  [commands addObject:inv];
  [self dequeueCommands];
}

- (void) dequeueCommands {
  if (!currentInvocation && commands.count > 0) {
    currentInvocation = commands[0];
    [commands removeObjectAtIndex:0];
    [self issueCommand:currentInvocation.cmd];
  }
}

- (void) issueCommand:(nonnull CmdBase*)cmd {
  if (dataCharacteristic == nil) {
    NSLog(@"Ignoring command issued before we have discovered characteristics");
    return;
  }
  NSLog(@"Writing command to data characteristic: %@", [cmd.data hexadecimalString]);
  // 255 is the real limit (buf limit in bgscript), but we set the limit at 220, as we need room for escaping special chars.
  if (cmd.data.length > 220) {
    NSLog(@"********** Warning: packet too large: %d bytes ************", cmd.data.length);
  } else {
    uint8_t count = cmd.data.length;
    NSMutableData *outBuf = [NSMutableData dataWithBytes:&count length:1];
    [outBuf appendData:cmd.data];
    [self.peripheral writeValue:outBuf forCharacteristic:dataCharacteristic type:CBCharacteristicWriteWithResponse];
  }
}

- (void) cancelCommand:(nonnull CmdBase*)cmd {
  if (currentInvocation.cmd == cmd) {
    currentInvocation = nil;
  }
  for (__CmdInvocation *inv in commands) {
    if (inv.cmd == cmd) {
      [commands removeObject:inv];
      break;
    }
  }
  [self dequeueCommands];
}


// TODO: this method needs to be called when a write response is finished.
- (void) sendTaskFinished {
  [self dequeueCommands];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  if (error) {
    NSLog(@"Could not write characteristic: %@", error);
    return;
  }
  if (characteristic == customNameCharacteristic) {
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];
  }
  //NSLog(@"Did write characteristic: %@", characteristic.UUID);
}

- (RileyLinkState) state {
  RileyLinkState rval;
  switch (self.peripheral.state) {
    case CBPeripheralStateConnected:
      rval = RileyLinkStateConnected;
      break;
    case CBPeripheralStateConnecting:
      rval = RileyLinkStateConnecting;
      break;
    default:
      rval = RileyLinkStateDisconnected;
      break;
  }
  return rval;
}

- (void) didDisconnect:(NSError*)error {
}

- (void)setCharacteristicsFromService:(CBService *)service {
  for (CBCharacteristic *characteristic in service.characteristics) {
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
      [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
      responseCountCharacteristic = characteristic;
      [self.peripheral readValueForCharacteristic:characteristic];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_DATA_UUID]]) {
      dataCharacteristic = characteristic;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_CUSTOM_NAME_UUID]]) {
      customNameCharacteristic = characteristic;
    }
  }
  
  NSDictionary *attrs = @{@"peripheral": self.peripheral};
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_ATTRS_DISCOVERED object:self userInfo:attrs];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  if (error) {
    NSLog(@"Failure while discovering services: %@", error);
    return;
  }
  //NSLog(@"didDiscoverServices: %@, %@", peripheral, peripheral.services);
  for (CBService *service in peripheral.services) {
    if ([service.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_SERVICE_UUID]]) {
      [peripheral discoverCharacteristics:[RileyLinkBLEManager UUIDsFromUUIDStrings:@[RILEYLINK_RESPONSE_COUNT_UUID,
                                                                                      RILEYLINK_DATA_UUID,
                                                                                      RILEYLINK_CUSTOM_NAME_UUID]
                                                                excludingAttributes:service.characteristics]
                               forService:service];
    }
  }
  // Discover other characteristics
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
  if (error != nil) {
    NSLog(@"Error reading RSSI: %@", [error localizedDescription]);
  } else {
    NSLog(@"RSSI for %@: %@", peripheral.name, RSSI);
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
  if (error) {
    [self cleanup];
    return;
  }
  
  [self setCharacteristicsFromService:service];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  if (error) {
    NSLog(@"Error updating %@: %@", characteristic, error);
    return;
  }
  NSLog(@"didUpdateValueForCharacteristic: %@", characteristic);
  
  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_DATA_UUID]]) {
    if (characteristic.value.length > 0) {
      [self dataReceivedFromRL:characteristic.value];
    }
    [self dequeueCommands];
  } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
    const unsigned char responseCount = ((const unsigned char*)[characteristic.value bytes])[0];
    NSLog(@"Updated response count: %d", responseCount);
    [peripheral readValueForCharacteristic:dataCharacteristic];
  }
}

- (void)dataReceivedFromRL:(NSData*) data {
  [inBuf appendData:data];
  
  NSRange endOfResp = [inBuf rangeOfData:endOfResponseMarker options:0 range:NSMakeRange(0, inBuf.length)];
  NSLog(@"******* New Data: %@", [data hexadecimalString]);
  
  NSData *fullResponse;
  
  if (endOfResp.location != NSNotFound) {
    fullResponse = [inBuf subdataWithRange:NSMakeRange(0, endOfResp.location)];
    NSLog(@"******* Full response: %@", [fullResponse hexadecimalString]);
    NSInteger remainder = inBuf.length - endOfResp.location - 1;
    if (remainder > 0) {
      inBuf = [[inBuf subdataWithRange:NSMakeRange(endOfResp.location+1, remainder)] mutableCopy];
      NSLog(@"******* Remainder: %@", [inBuf hexadecimalString]);
    } else {
      inBuf = [NSMutableData data];
    }
  } else {
    NSLog(@"******* Buffering: %@", [inBuf hexadecimalString]);
  }
  
  if (fullResponse) {
    if (currentInvocation && fullResponse.length > 1) {
      currentInvocation.cmd.response = fullResponse;
      if (currentInvocation.completionHandler != nil) {
        currentInvocation.completionHandler(currentInvocation.cmd);
      }
      currentInvocation = nil;
      if (commands.count == 0) {
        [self onIdle];
      }
    } else {
      [self handleIdleListenerResponse:fullResponse];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  NSLog(@"Updated notification state for %@, %@", characteristic, error);
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];
}

- (void)cleanup {
  NSLog(@"Entering cleanup");
  
  // See if we are subscribed to a characteristic on the peripheral
  for (CBService *service in self.peripheral.services) {
    for (CBCharacteristic *characteristic in service.characteristics) {
      if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
        if (characteristic.isNotifying) {
          [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
          return;
        }
      }
    }
  }
  
  dataCharacteristic = nil;
  responseCountCharacteristic = nil;
  customNameCharacteristic = nil;
}

- (NSString*) deviceURI {
  return [@"rl://" stringByAppendingString:self.name];
}

- (void) setCustomName:(nonnull NSString*)customName {
  if (customNameCharacteristic) {
    NSData *data = [customName dataUsingEncoding:NSUTF8StringEncoding];
    [self.peripheral writeValue:data forCharacteristic:customNameCharacteristic type:CBCharacteristicWriteWithResponse];
  } else {
    NSLog(@"Missing customNameCharacteristic");
  }
  
}

- (void) onIdle {
  if (idleListeningEnabled) {
    GetPacketCmd *cmd = [[GetPacketCmd alloc] init];
    cmd.listenChannel = idleListenChannel;
    cmd.timeoutMS = 60 * 1000;
    [self issueCommand:cmd];
  }
}

- (void) enableIdleListeningOnChannel:(uint8_t)channel {
  idleListeningEnabled = YES;
  idleListenChannel = channel;
  if (commands.count == 0 && currentInvocation == nil) {
    [self onIdle];
  }
}

- (void) disableIdleListening {
  idleListeningEnabled = NO;
}

- (void) handleIdleListenerResponse:(NSData *)response {
  if (response.length > 3) {
    // This is a response to our idle listen command
    MinimedPacket *packet = [[MinimedPacket alloc] initWithData:response];
    packet.capturedAt = [NSDate date];
    //if ([packet isValid]) {
    [incomingPackets addObject:packet];
    NSLog(@"Read packet (%d): %@", packet.rssi, packet.data.hexadecimalString);
    NSDictionary *attrs = @{
                            @"packet": packet,
                            @"peripheral": self.peripheral,
                            };
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_PACKET_RECEIVED object:self userInfo:attrs];
  } else {
    NSLog(@"Idle timeout");
  }
  [self onIdle];
}

@end
