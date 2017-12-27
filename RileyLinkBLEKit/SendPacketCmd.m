//
//  SendPacketCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 12/27/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "SendPacketCmd.h"
#import "RileyLinkBLEKit/RileyLinkBLEKit-Swift.h"

@implementation SendPacketCmd

- (NSData*)data {
    uint8_t cmd[4];
    cmd[0] = RILEYLINK_CMD_SEND_PACKET;
    cmd[1] = _sendChannel;
    cmd[2] = _repeatCount;
    cmd[3] = _msBetweenPackets;
    
    NSMutableData *serialized = [NSMutableData dataWithBytes:cmd length:4];
    if (_outgoingData) {
        [serialized appendData:_outgoingData];
    }
    return serialized;
}


@end
