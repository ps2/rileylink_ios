//
//  RileyLinkBLE.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "MinimedPacket.h"
#import "RileyLinkBLEDevice.h"
#import "RileyLinkBLEManager.h"
#import "NSData+Conversion.h"
#import "SendDataTask.h"

@interface RileyLinkBLEDevice () <CBPeripheralDelegate> {
  CBCharacteristic *packetRxCharacteristic;
  CBCharacteristic *packetTxCharacteristic;
  CBCharacteristic *txTriggerCharacteristic;
  CBCharacteristic *packetRssiCharacteristic;
  CBCharacteristic *packetCountCharacteristic;
  CBCharacteristic *txChannelCharacteristic;
  CBCharacteristic *rxChannelCharacteristic;
  CBCharacteristic *customNameCharacteristic;
  NSMutableArray *incomingPackets;
  NSMutableArray *sendTasks;
  SendDataTask *currentSendTask;
  NSInteger copiesLeftToSend;
  NSTimer *sendTimer;
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
        sendTasks = [NSMutableArray array];
        currentSendTask = nil;

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

- (void) sendPacketData:(NSData*)data {
  [self sendPacketData:data withCount:1 andTimeBetweenPackets:0];
}

- (void) sendPacketData:(NSData*)data withCount:(NSInteger)count andTimeBetweenPackets:(NSTimeInterval)timeBetweenPackets {
  if (count <= 0) {
    NSLog(@"Invalid repeat count for sendPacketData");
    return;
  }
  SendDataTask *task = [[SendDataTask alloc] init];
  task.data = data;
  task.repeatCount = count;
  task.timeBetweenPackets = timeBetweenPackets;
  [sendTasks addObject:task];
  [self dequeueSendTasks];
}

- (void) dequeueSendTasks {
  if (!currentSendTask && sendTasks.count > 0) {
    currentSendTask = sendTasks[0];
    copiesLeftToSend = currentSendTask.repeatCount;
    [sendTasks removeObjectAtIndex:0];
    NSLog(@"Prepping for send: %@", [currentSendTask.data hexadecimalString]);
    [self.peripheral writeValue:currentSendTask.data forCharacteristic:packetTxCharacteristic type:CBCharacteristicWriteWithResponse];
  }
}

- (void) triggerSend {
  if (copiesLeftToSend > 0) {
    NSLog(@"Sending copy %zd", (currentSendTask.repeatCount - copiesLeftToSend) + 1);
    NSData *trigger = [NSData dataWithHexadecimalString:@"01"];
    [self.peripheral writeValue:trigger forCharacteristic:txTriggerCharacteristic type:CBCharacteristicWriteWithResponse];
    copiesLeftToSend--;
  }
  
  if (copiesLeftToSend > 0) {
    if (!sendTimer) {
      sendTimer = [NSTimer timerWithTimeInterval:currentSendTask.timeBetweenPackets target:self selector:@selector(triggerSend) userInfo:nil repeats:YES];
      [[NSRunLoop currentRunLoop] addTimer:sendTimer forMode:NSRunLoopCommonModes];
    }
  }
  else {
    currentSendTask = nil;
    [sendTimer invalidate];
    sendTimer = nil;
    [self dequeueSendTasks];
  }
}

- (void) cancelSending {
  [sendTimer invalidate];
  sendTimer = nil;
  copiesLeftToSend = 0;
  currentSendTask = nil;
  [self dequeueSendTasks];
}

- (void) setRXChannel:(unsigned char)channel {
  if (rxChannelCharacteristic) {
    NSData *data = [NSData dataWithBytes:&channel length:1];
    [self.peripheral writeValue:data forCharacteristic:rxChannelCharacteristic type:CBCharacteristicWriteWithResponse];
  } else {
    NSLog(@"Missing rx channel characteristic");
  }
}

- (void) setTXChannel:(unsigned char)channel {
  if (rxChannelCharacteristic) {
    NSData *data = [NSData dataWithBytes:&channel length:1];
    [self.peripheral writeValue:data forCharacteristic:txChannelCharacteristic type:CBCharacteristicWriteWithResponse];
  } else {
    NSLog(@"Missing tx channel characteristic");    
  }
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  if (error) {
    NSLog(@"Could not write characteristic: %@", error);
    return;
  }
  if (characteristic == packetTxCharacteristic) {
    [self triggerSend];
  }
  if (characteristic == customNameCharacteristic) {
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];
  }
  NSLog(@"Did write characteristic: %@", characteristic.UUID);
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

- (void) connect {
  [[RileyLinkBLEManager sharedManager] connectToRileyLink:self];
}

- (void) disconnect {
  [[RileyLinkBLEManager sharedManager] disconnectRileyLink:self];
}

- (void) didDisconnect:(NSError*)error {
  if (currentSendTask) {
    [self cancelSending];
  }
}

- (void)setCharacteristicsFromService:(CBService *)service {
  for (CBCharacteristic *characteristic in service.characteristics) {
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_PACKET_COUNT]]) {
      [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
      packetCountCharacteristic = characteristic;
      [self.peripheral readValueForCharacteristic:characteristic];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RX_CHANNEL_UUID]]) {
      rxChannelCharacteristic = characteristic;
      [self setRXChannel:2];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_TX_CHANNEL_UUID]]) {
      txChannelCharacteristic = characteristic;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RX_PACKET_UUID]]) {
      packetRxCharacteristic = characteristic;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_TX_PACKET_UUID]]) {
      packetTxCharacteristic = characteristic;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_TX_TRIGGER_UUID]]) {
      txTriggerCharacteristic = characteristic;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_CUSTOM_NAME_UUID]]) {
      customNameCharacteristic = characteristic;
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  if (error) {
    NSLog(@"Failure while discovering services: %@", error);
    return;
  }
  //NSLog(@"didDiscoverServices: %@, %@", peripheral, peripheral.services);
  for (CBService *service in peripheral.services) {
    if ([service.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_SERVICE_UUID]]) {
        [peripheral discoverCharacteristics:[RileyLinkBLEManager UUIDsFromUUIDStrings:@[RILEYLINK_RX_PACKET_UUID,
                                                                                        RILEYLINK_RX_CHANNEL_UUID,
                                                                                        RILEYLINK_TX_CHANNEL_UUID,
                                                                                        RILEYLINK_PACKET_COUNT,
                                                                                        RILEYLINK_TX_PACKET_UUID,
                                                                                        RILEYLINK_TX_TRIGGER_UUID,
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
  //NSLog(@"didUpdateValueForCharacteristic: %@", characteristic);
  
  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RX_PACKET_UUID]]) {
    if (characteristic.value.length > 0) {
      MinimedPacket *packet = [[MinimedPacket alloc] initWithData:characteristic.value];
      packet.capturedAt = [NSDate date];
      //if ([packet isValid]) {
      [incomingPackets addObject:packet];
      NSLog(@"Read packet (%d): %@", packet.rssi, packet.data.hexadecimalString);
      NSDictionary *attrs = @{
                              @"packet": packet,
                              @"peripheral": self.peripheral,
                              };
      [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_PACKET_RECEIVED object:self userInfo:attrs];
    }
    [peripheral readValueForCharacteristic:packetRxCharacteristic];
    
  } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_PACKET_COUNT]]) {
    const unsigned char packetCount = ((const unsigned char*)[characteristic.value bytes])[0];
    NSLog(@"Updated packet count: %d", packetCount);
    if (packetCount > 0) {
      [peripheral readValueForCharacteristic:packetRxCharacteristic];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  
  if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_PACKET_COUNT]]) {
    return;
  }
  
//  if (characteristic.isNotifying) {
//    NSLog(@"Notification began on %@", characteristic.);
//  } else {
//    // Notification has stopped
//  }
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];
}

- (void)cleanup {
  NSLog(@"Entering cleanup");
  
  // See if we are subscribed to a characteristic on the peripheral
  if (self.peripheral.services != nil) {
    for (CBService *service in self.peripheral.services) {
      if (service.characteristics != nil) {
        for (CBCharacteristic *characteristic in service.characteristics) {
          if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_PACKET_COUNT]]) {
            if (characteristic.isNotifying) {
              [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
              return;
            }
          }
        }
      }
    }
  }
  
  packetRxCharacteristic = nil;
  packetTxCharacteristic = nil;
  txTriggerCharacteristic = nil;
  packetRssiCharacteristic = nil;
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


@end
