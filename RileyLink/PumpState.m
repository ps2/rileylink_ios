//
//  PumpState.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/6/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpState.h"
#import "NSData+Conversion.h"
#import "SendPacketCmd.h"
#import "SendAndListenCmd.h"
#import "RileyLinkBLEDevice.h"
#import "MinimedPacket.h"
#import "MessageBase.h"
#import "UpdateRegisterCmd.h"

@implementation PumpState

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)a_pumpId {
  self = [super init];
  if (self) {
    _pumpId = a_pumpId;
  }
  return self;
}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (BOOL) isAwake {
  return (_awakeUntil != nil && [_awakeUntil timeIntervalSinceNow] > 0);
}


@end
