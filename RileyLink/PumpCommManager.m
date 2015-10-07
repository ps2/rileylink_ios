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

- (MessageBase *)powerMessage
{
  return [self powerMessageWithArgs:@"00"];
}

- (MessageBase *)powerMessageWithArgs:(NSString *)args
{
  NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@5D%@", pumpId, args];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (void)wakeup:(NSTimeInterval)duration {
  
  if ([self isAwake] || waking) {
    return;
  }
  
  waking = YES;

  MessageSendOperation *wakeupOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                               message:[self powerMessage]
                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                       if (operation.responsePacket != nil) {
                                                                         NSLog(@"Pump acknowledged wakeup!");
                                                                       } else {
                                                                         NSLog(@"Power on error: %@", operation.error);
                                                                       }
                                                                     }];
  
  wakeupOperation.repeatInterval = 0.078;
  wakeupOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;
  [self.pumpCommQueue addOperation:wakeupOperation];
  
  unsigned char minutes = floor(duration/60);
  
  NSString *msg = [NSString stringWithFormat:@"0201%02x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", minutes];
  
  MessageSendOperation *wakeupArgsOperation = [[MessageSendOperation alloc] initWithDevice:device
                                                                                   message:[self powerMessageWithArgs:msg]
                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
                                                                           if (operation.responsePacket != nil) {
                                                                             NSLog(@"Power on for %d minutes", minutes);
                                                                             awakeUntil = [NSDate dateWithTimeIntervalSinceNow:duration];
                                                                           } else {
                                                                             NSLog(@"Power on with args error: %@", operation.error);
                                                                           }
                                                                           waking = NO;
                                                                         }];
  wakeupArgsOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;
  [self.pumpCommQueue addOperation:wakeupArgsOperation];
}

- (BOOL) isAwake {
  return (awakeUntil != nil && [awakeUntil timeIntervalSinceNow] > 0);
}

- (void) getHistoryPage {
  [self wakeup:30];
  
  
}

@end
