//
//  GetVersionCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "GetVersionCmd.h"

@implementation GetVersionCmd

- (NSData*)data {
    uint8_t cmd[1];
    cmd[0] = RILEYLINK_CMD_GET_VERSION;
    return [NSData dataWithBytes:cmd length:1];
}

@end
