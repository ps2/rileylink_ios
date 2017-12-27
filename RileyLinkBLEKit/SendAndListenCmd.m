//
//  SendDataCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 8/9/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "SendAndListenCmd.h"
#import "RileyLinkBLEManager.h"
#import "RileyLinkBLEKit/RileyLinkBLEKit-Swift.h"

@implementation SendAndListenCmd

- (NSData*)data {
    uint8_t cmd[10];
    cmd[0] = RILEYLINK_CMD_SEND_AND_LISTEN;
    cmd[1] = _sendChannel;
    cmd[2] = _repeatCount;
    cmd[3] = _msBetweenPackets;
    cmd[4] = _listenChannel;
    cmd[5] = _timeoutMS >> 24;
    cmd[6] = (_timeoutMS >> 16) & 0xff;
    cmd[7] = (_timeoutMS >> 8) & 0xff;
    cmd[8] = _timeoutMS & 0xff;
    cmd[9] = _retryCount;
    
    NSMutableData *serialized = [NSMutableData dataWithBytes:cmd length:10];
    if (_outgoingData) {
        [serialized appendData:_outgoingData];
    }
    return serialized;
}

@end
