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
  uint8_t cmd[4];
  cmd[0] = RILEYLINK_CMD_GET_PACKET;
  cmd[1] = _listenChannel;

  for (int i = 0; i < 4; i++) {
    cmd[2 + i] = _timeoutMS >> ((3 - i) * 8) & 0xff;
  }

  return [NSData dataWithBytes:cmd length:6];
}

@end
