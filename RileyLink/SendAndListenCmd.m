//
//  SendDataCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 8/9/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "SendAndListenCmd.h"
#import "RileyLinkBLEManager.h"

@implementation SendAndListenCmd

- (NSData*)data {
  uint8_t cmd[8];
  cmd[0] = RILEYLINK_CMD_SEND_AND_LISTEN;
  cmd[1] = _sendChannel;
  cmd[2] = _repeatCount;
  cmd[3] = _msBetweenPackets;
  cmd[4] = _listenChannel;

  for (int i = 0; i < 4; i++) {
    cmd[5 + i] = _timeoutMS >> ((3 - i) * 8) & 0xff;
  }

  cmd[7] = _retryCount;
  
  NSMutableData *serialized = [NSMutableData dataWithBytes:cmd length:10];
  [serialized appendData:_packet];
  uint8_t nullTerminator = 0;
  [serialized appendBytes:&nullTerminator length:1];
  return serialized;
}

@end
