//
//  GetPacketCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "GetPacketCmd.h"

@implementation GetPacketCmd 

- (NSData*)data {
  uint8_t cmd[6];
  cmd[0] = RILEYLINK_CMD_GET_PACKET;
  cmd[1] = _listenChannel;
  cmd[2] = _timeoutMS >> 24;
  cmd[3] = (_timeoutMS >> 16) & 0xff;
  cmd[4] = (_timeoutMS >> 8) & 0xff;
  cmd[5] = _timeoutMS & 0xff;
  
  return [NSData dataWithBytes:cmd length:6];
}

@end
