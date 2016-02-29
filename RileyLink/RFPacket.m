//
//  RFPacket.m
//  RileyLink
//
//  Created by Pete Schwamb on 2/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "RFPacket.h"

@implementation RFPacket

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (instancetype)initWithData:(NSData*)data
{
  self = [super init];
  if (self) {
    if (data.length > 0) {
      unsigned char rssiDec = ((const unsigned char*)[data bytes])[0];
      unsigned char rssiOffset = 73;
      if (rssiDec >= 128) {
        self.rssi = (short)((short)( rssiDec - 256) / 2) - rssiOffset;
      } else {
        self.rssi = (rssiDec / 2) - rssiOffset;
      }
    }
    if (data.length > 1) {
      self.packetNumber = ((const unsigned char*)[data bytes])[1];
    }
    
    if (data.length > 2) {
      _data = [data subdataWithRange:NSMakeRange(2, data.length - 2)];
    }
  }
  return self;
}

@end
