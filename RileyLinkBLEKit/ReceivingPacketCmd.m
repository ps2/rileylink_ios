//
//  ReceivingPacketCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "ReceivingPacketCmd.h"
#import "RileyLinkBLEKit/RileyLinkBLEKit-Swift.h"

@implementation ReceivingPacketCmd

- (RFPacket*) receivedPacket {
    RFPacket *packet;

    if (self.response != nil) {
        packet = [[RFPacket alloc] initWithRfspyResponse:self.response];
    }
    return packet;
}

- (BOOL) didReceiveResponse {
    return self.response != nil && self.response.length > 2;
}

@end
