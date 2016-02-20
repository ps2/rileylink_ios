//
//  UpdateRegisterCmd.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/25/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "UpdateRegisterCmd.h"

@implementation UpdateRegisterCmd

- (NSData*)data {
  uint8_t cmd[4];
  cmd[0] = RILEYLINK_CMD_UPDATE_REGISTER;
  cmd[1] = _addr;
  cmd[2] = _value;  
  return [NSData dataWithBytes:cmd length:4];
}

@end
