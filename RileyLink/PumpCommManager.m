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

#define STANDARD_PUMP_RESPONSE_WINDOW 180

@interface PumpCommManager () {
  NSDate *awakeUntil;
  BOOL waking;
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


- (void)wakeup:(uint8_t)durationMinutes {
  
  if ([self isAwake] || waking) {
    return;
  }
  
  waking = YES;

  MessageSendOperation *wakeupOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                               message:[self powerMessage]
                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                       if (operation.responsePacket != nil) {
                                                                         NSLog(@"Pump acknowledged wakeup!");
                                                                       } else {
                                                                         // Can we clear the queue here?  Since the pump didn't wake.
                                                                         NSLog(@"Power on error: %@", operation.error);
                                                                         [self.pumpCommQueue cancelAllOperations];
                                                                       }
                                                                     }];
  
  wakeupOperation.waitTimeMS = 15000;
  wakeupOperation.repeatCount = 200;
  wakeupOperation.msBetweenPackets = 0;
  wakeupOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:wakeupOperation];
  
  NSString *msg = [NSString stringWithFormat:@"0201%02x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", durationMinutes];
  
  MessageSendOperation *wakeupArgsOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                                   message:[self powerMessageWithArgs:msg]
                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                           if (operation.responsePacket != nil) {
                                                                             NSLog(@"Power on for %d minutes", durationMinutes);
                                                                             awakeUntil = [NSDate dateWithTimeIntervalSinceNow:durationMinutes*60];
                                                                           } else {
                                                                             NSLog(@"Power on with args error: %@", operation.error);
                                                                           }
                                                                           waking = NO;
                                                                         }];
  wakeupArgsOperation.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
  wakeupArgsOperation.retryCount = 3;
  wakeupArgsOperation.responseMessageType = MESSAGE_TYPE_ACK;
  [self.pumpCommQueue addOperation:wakeupArgsOperation];
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
  [self wakeIfNeeded];
  MessageSendOperation *buttonPressOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                               message:[self buttonPressMessage]
                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                       if (operation.responsePacket != nil) {
                                                                         NSLog(@"Pump acknowledged button press (no args)!");
                                                                       } else {
                                                                         NSLog(@"Error sending button press: %@", operation.error);
                                                                       }
                                                                     }];
  buttonPressOperation.responseMessageType = MESSAGE_TYPE_ACK;
  buttonPressOperation.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;

  [self.pumpCommQueue addOperation:buttonPressOperation];
  
  MessageSendOperation *buttonPressArgsOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                                   message:[self buttonPressMessageWithArgs:@"0104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"]
                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                           if (operation.responsePacket != nil) {
                                                                             NSLog(@"button press down!");
                                                                           } else {
                                                                             NSLog(@"Button press error: %@", operation.error);
                                                                           }
                                                                         }];
  buttonPressArgsOperation.responseMessageType = MESSAGE_TYPE_ACK;
  buttonPressArgsOperation.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
  [self.pumpCommQueue addOperation:buttonPressArgsOperation];
}

- (MessageBase *)modelQueryMessage
{
  NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pumpId, MESSAGE_TYPE_GET_PUMP_MODEL];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (void) getPumpModel:(void (^ _Nullable)(NSString*))completionHandler {
  [self wakeIfNeeded];

  MessageSendOperation *modelQueryOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                                   message:[self modelQueryMessage]
                                               completionHandler:^(MessageSendOperation * _Nonnull operation) {
      if (operation.responsePacket != nil) {
          NSString *version = [NSString stringWithCString:&[operation.responsePacket.data bytes][7] encoding:NSASCIIStringEncoding];
        completionHandler(version);
      } else {
        completionHandler(nil);
      }
  }];
  modelQueryOperation.responseMessageType = MESSAGE_TYPE_GET_PUMP_MODEL;
  modelQueryOperation.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
  [self.pumpCommQueue addOperation:modelQueryOperation];
}

- (MessageBase *)batteryStatusMessage
{
    NSString *packetStr = [NSString stringWithFormat:@"%02x%@%02x00", PacketTypeCarelink, _pumpId, MESSAGE_TYPE_GET_BATTERY];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}


- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler {
  [self wakeIfNeeded];
  MessageSendOperation *batteryStatusOperation = [[MessageSendOperation alloc] initWithDevice:_device
                                                                                      message:[self batteryStatusMessage]
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
  batteryStatusOperation.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;

  [self.pumpCommQueue addOperation:batteryStatusOperation];
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

- (void) dumpHistoryPage:(uint8_t)pageNum completionHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler {
  [self wakeIfNeeded];
  
  NSMutableDictionary *responseDict = [NSMutableDictionary dictionary];
  NSMutableArray *responses = [NSMutableArray array];
  
  __block NSInteger finishedCount = 0;
  __block NSInteger frameCrcErrorCount = 0;
  __block NSInteger missedResponseCount = 0;
  
  MessageBase *dumpHistMsg = [self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"00"];
  
  MessageSendOperation *dumpHistOp = [[MessageSendOperation alloc] initWithDevice:_device
                                                                          message:dumpHistMsg
                                                                            completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                              if (operation.responsePacket != nil) {
                                                                                NSLog(@"Pump acked dump msg (0x80)");
                                                                              } else {
                                                                                NSLog(@"Error requesting pump dump: %@", operation.error);
                                                                              }
  }];
  dumpHistOp.responseMessageType = MESSAGE_TYPE_ACK;
  dumpHistOp.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
  dumpHistOp.retryCount = 3;
  [self.pumpCommQueue addOperation:dumpHistOp];
  
  NSString *dumpHistArgs = [NSString stringWithFormat:@"01%02x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", pageNum];


  MessageBase *dumpHistMsgArgs = [self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:dumpHistArgs];
  MessageSendOperation *dumpHistOpArgs = [[MessageSendOperation alloc] initWithDevice:_device
                                                                          message:dumpHistMsgArgs
                                                                completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                  if (operation.responsePacket != nil) {
                                                                    [responses addObject:operation.responsePacket.data];
                                                                  } else {
                                                                    NSLog(@"Error requesting pump dump with args: %@", operation.error);
                                                                  }
                                                                }];
  dumpHistOpArgs.responseMessageType = MESSAGE_TYPE_READ_HISTORY;
  dumpHistOpArgs.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
  dumpHistOpArgs.retryCount = 3;
  
  [self.pumpCommQueue addOperation:dumpHistOpArgs];
  
  // TODO: send 16 acks, and expect 15 more dumps
  for (int i=0; i<16; i++) {
    MessageBase *ack = [self msgType:MESSAGE_TYPE_ACK withArgs:@"00"];
    MessageSendOperation *ackOp = [[MessageSendOperation alloc] initWithDevice:_device
                                                                                message:ack
                                                                      completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                        finishedCount++;
                                                                        if (operation.responsePacket != nil) {
                                                                          if (![operation.responsePacket isValid]) {
                                                                            NSLog(@"Invalid history page packet!");
                                                                            frameCrcErrorCount++;
                                                                          }
                                                                          [responses addObject:operation.responsePacket.data];
                                                                          if (responses.count == 16) {
                                                                            responseDict[@"pageData"] = [self parseFramesIntoHistoryPage:responses];
                                                                          }
                                                                        } else if (operation.responseMessageType != 0) {
                                                                          missedResponseCount++;
                                                                          NSLog(@"Error requesting pump dump with args: %@", operation.error);
                                                                        }
                                                                        if (finishedCount == 16) {
                                                                          responseDict[@"frameCrcErrorCount"] = [NSNumber numberWithLong:frameCrcErrorCount];
                                                                          responseDict[@"missedResponseCount"] = [NSNumber numberWithLong:missedResponseCount];
                                                                          responseDict[@"totalErrorCount"] = [NSNumber numberWithLong:(missedResponseCount+frameCrcErrorCount)];
                                                                          completionHandler(responseDict);
                                                                        }
                                                                      }];
    
    // Last packet doesn't need a response
    if (i < 15) {
      ackOp.responseMessageType = MESSAGE_TYPE_READ_HISTORY;
      ackOp.waitTimeMS = STANDARD_PUMP_RESPONSE_WINDOW;
      ackOp.retryCount = 3;
    }
    [self.pumpCommQueue addOperation:ackOp];
  }
}

@end
