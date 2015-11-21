//
//  PumpCommManager.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/6/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpCommManager.h"
#import "MessageSendOperation.h"
#import "NSData+Conversion.h"

@interface PumpCommManager () {
  RileyLinkBLEDevice *device;
  NSString *pumpId;
  NSDate *awakeUntil;
  BOOL waking;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;

@end

@implementation PumpCommManager

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)a_pumpId andDevice:(nonnull RileyLinkBLEDevice *)a_device {
  self = [super init];
  if (self) {
    pumpId = a_pumpId;
    device = a_device;
    
    self.pumpCommQueue = [[NSOperationQueue alloc] init];
    self.pumpCommQueue.maxConcurrentOperationCount = 1;
    self.pumpCommQueue.qualityOfService = NSQualityOfServiceUserInitiated;
  }
  return self;

}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (MessageBase *)msgType:(unsigned char)t withArgs:(NSString *)args {
  NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@%02x%@", pumpId, t, args];
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


- (void)wakeup:(NSTimeInterval)duration {
  
  if ([self isAwake] || waking) {
    return;
  }
  
  waking = YES;

  MessageSendOperation *wakeupOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                               message:[self powerMessage]
                                                                               timeout:15
                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                       if (operation.responsePacket != nil) {
                                                                         NSLog(@"Pump acknowledged wakeup!");
                                                                       } else {
                                                                         NSLog(@"Power on error: %@", operation.error);
                                                                       }
                                                                     }];
  
  wakeupOperation.repeatInterval = 0.078;
  wakeupOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:wakeupOperation];
  
  unsigned char minutes = floor(duration/60);
  
  NSString *msg = [NSString stringWithFormat:@"0201%02x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", minutes];
  
  MessageSendOperation *wakeupArgsOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                                   message:[self powerMessageWithArgs:msg]
                                                                                   timeout:10
                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                           if (operation.responsePacket != nil) {
                                                                             NSLog(@"Power on for %d minutes", minutes);
                                                                             awakeUntil = [NSDate dateWithTimeIntervalSinceNow:duration];
                                                                           } else {
                                                                             NSLog(@"Power on with args error: %@", operation.error);
                                                                           }
                                                                           waking = NO;
                                                                         }];
  wakeupArgsOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:wakeupArgsOperation];
}

- (BOOL) isAwake {
  return (awakeUntil != nil && [awakeUntil timeIntervalSinceNow] > 0);
}

- (void) wakeIfNeeded {
  [self wakeup:10*60];
}

- (void) getHistoryPage {
  // TODO
}

- (void) pressButton {
  [self wakeIfNeeded];
  MessageSendOperation *buttonPressOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                               message:[self buttonPressMessage]
                                                                               timeout:10
                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                       if (operation.responsePacket != nil) {
                                                                         NSLog(@"Pump acknowledged button press (no args)!");
                                                                       } else {
                                                                         NSLog(@"Error sending button press: %@", operation.error);
                                                                       }
                                                                     }];
  buttonPressOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:buttonPressOperation];
  
  MessageSendOperation *buttonPressArgsOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                                   message:[self buttonPressMessageWithArgs:@"0104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"]
                                                                                   timeout:10
                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                           if (operation.responsePacket != nil) {
                                                                             NSLog(@"button press down!");
                                                                           } else {
                                                                             NSLog(@"Button press error: %@", operation.error);
                                                                           }
                                                                         }];
  buttonPressArgsOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:buttonPressArgsOperation];
}

- (MessageBase *)modelQueryMessage
{
  NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@%02x00", pumpId, MESSAGE_TYPE_GET_PUMP_MODEL];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (void) getPumpModel:(void (^ _Nullable)(NSString*))completionHandler {
  [self wakeIfNeeded];

  MessageSendOperation *modelQueryOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                                   message:[self modelQueryMessage]
                                                                                   timeout:10
                                               completionHandler:^(MessageSendOperation * _Nonnull operation) {
      if (operation.responsePacket != nil) {
          NSString *version = [NSString stringWithCString:&[operation.responsePacket.data bytes][7] encoding:NSASCIIStringEncoding];
        completionHandler(version);
      } else {
        completionHandler(@"Unknown");
      }
  }];
  modelQueryOperation.responseMessageType = MESSAGE_TYPE_GET_PUMP_MODEL;
  [self.pumpCommQueue addOperation:modelQueryOperation];
}

- (MessageBase *)batteryStatusMessage
{
  NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@%02x00", pumpId, MESSAGE_TYPE_GET_BATTERY];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}


- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler {
  [self wakeIfNeeded];
  MessageSendOperation *batteryStatusOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                                      message:[self batteryStatusMessage]
                                                                                      timeout:10
                                                                            completionHandler:^(MessageSendOperation * _Nonnull operation) {
      if (operation.responsePacket != nil) {
          unsigned char *data = (unsigned char *)[operation.responsePacket.data bytes] + 6;

          NSInteger volts = (((int)data[1]) << 8) + data[2];
          NSString *indicator = data[0] ? @"Low" : @"Normal";
        completionHandler(indicator, volts/100.0);
      } else {
        completionHandler(@"Unknown", 0.0);
      }
  }];
  batteryStatusOperation.responseMessageType = MESSAGE_TYPE_GET_BATTERY;

  [self.pumpCommQueue addOperation:batteryStatusOperation];
}

- (NSData*)parseFramesIntoHistoryPage:(NSArray*)packets {
  NSMutableData *data = [NSMutableData data];
  
  NSRange r = NSMakeRange(6, 64);
  for (NSData *frame in packets) {
    [data appendData:[frame subdataWithRange:r]];
  }
  return data;
}

- (void) dumpHistory:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler {
  [self wakeIfNeeded];
  
  NSMutableDictionary *pages = [NSMutableDictionary dictionary];
  NSMutableArray *responses = [NSMutableArray array];
  
  MessageBase *dumpHistMsg = [self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"00"];
  
  MessageSendOperation *dumpHistOp = [[MessageSendOperation alloc] initWithDevice:device
                                                                          message:dumpHistMsg
                                                                          timeout:2
                                                                            completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                              if (operation.responsePacket != nil) {
                                                                                NSLog(@"Pump acked dump msg (0x80)");
                                                                              } else {
                                                                                NSLog(@"Error requesting pump dump: %@", operation.error);
                                                                              }
  }];
  dumpHistOp.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:dumpHistOp];
  
  MessageBase *dumpHistMsgArgs = [self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"];
  MessageSendOperation *dumpHistOpArgs = [[MessageSendOperation alloc] initWithDevice:device
                                                                          message:dumpHistMsgArgs
                                                                              timeout:2
                                                                completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                  if (operation.responsePacket != nil) {
                                                                    [responses addObject:operation.responsePacket.data];
                                                                  } else {
                                                                    NSLog(@"Error requesting pump dump with args: %@", operation.error);
                                                                  }
                                                                }];
  dumpHistOpArgs.responseMessageType = MESSAGE_TYPE_READ_HISTORY;
  [self.pumpCommQueue addOperation:dumpHistOpArgs];
  
  // TODO: send 15 acks, and expect 15 more dumps
  for (int i=0; i<16; i++) {
    MessageBase *ack = [self msgType:MESSAGE_TYPE_ACK withArgs:@"00"];
    MessageSendOperation *ackOp = [[MessageSendOperation alloc] initWithDevice:device
                                                                                message:ack
                                                                        timeout:2
                                                                      completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                        if (operation.responsePacket != nil) {
                                                                          [responses addObject:operation.responsePacket.data];
                                                                          if (responses.count == 16) {
                                                                            pages[@"page0"] = [self parseFramesIntoHistoryPage:responses];
                                                                            completionHandler(pages);
                                                                          }
                                                                        } else if (operation.responseMessageType != 0) {
                                                                          NSLog(@"Error requesting pump dump with args: %@", operation.error);
                                                                        }
                                                                      }];
    
    // Last packet doesn't need a response
    if (i < 15) {
      ackOp.responseMessageType = MESSAGE_TYPE_READ_HISTORY;
    }
    [self.pumpCommQueue addOperation:ackOp];
  }
  NSLog(@"Received %d packets", responses.count);
  


}

@end
