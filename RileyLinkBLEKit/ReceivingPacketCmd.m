//
//  ReceivingPacketCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "ReceivingPacketCmd.h"

@implementation ReceivingPacketCmd

- (RFPacket*) receivedPacket {
  if (_receivedPacket == nil && self.response != nil) {
    _receivedPacket = [[RFPacket alloc] initWithRFSPYResponse:self.response];
  }
  return _receivedPacket;
}

@end
