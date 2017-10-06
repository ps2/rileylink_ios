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
    if (_receivedPacket == nil && self.response != nil) {
        _receivedPacket = [[RFPacket alloc] initWithRfspyResponse:self.response];
    }
    return _receivedPacket;
}

- (BOOL) didReceiveResponse {
    return self.response != nil && self.response.length > 2;
}

- (NSData*) rawReceivedData {
    if (self.didReceiveResponse) {
        return [self.response subdataWithRange:NSMakeRange(2, self.response.length - 2)];
    } else {
        return nil;
    }
}

@end
