//
//  MessageBase.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 5/26/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "MessageBase.h"

@interface MessageBase ()

@property (nonatomic, nonnull, strong) NSData *data;

@end

@implementation MessageBase

- (instancetype)init NS_UNAVAILABLE
{
    return nil;
}

- (instancetype)initWithData:(NSData*)data
{
  self = [super init];
  if (self) {
    _data = data;
  }
  return self;
}

- (NSDictionary*) bitBlocks {
  return @{};
}

- (unsigned char) getBitAtIndex:(NSInteger)idx {
  NSInteger byteOffset = idx/8;
  int posBit = idx%8;
  if (byteOffset < _data.length) {
    unsigned char valByte = ((unsigned char*)_data.bytes)[byteOffset];
    return valByte>>(8-(posBit+1)) & 0x1;
  } else {
    return 0;
  }
}

- (NSInteger)bitsOffset {
  return 5;
}

- (NSInteger) getBits:(NSString*)key {
  NSArray *range = [self bitBlocks][key];
  NSInteger bitsNeeded = [[range lastObject] integerValue];
  // bitBlocks start at byte idx 5
  NSInteger offset = [[range firstObject] integerValue] + ([self bitsOffset]*8);
  NSInteger rval = 0;
  while (bitsNeeded > 0) {
    rval = (rval << 1) + [self getBitAtIndex:offset++];
    bitsNeeded--;
  }
  return rval;
}

- (void) setBits:(NSString*)key toValue:(NSInteger)val {
  //TODO
}

- (unsigned char)byteAt:(NSInteger)index {
    if (_data && index < [_data length]) {
        return ((unsigned char*)[_data bytes])[index];
    } else {
        return 0;
    }
}

- (PacketType) packetType {
    return [self byteAt:0];
}

- (MessageType) messageType {
    return [self byteAt:4];
}

- (NSString*) address {
    return [NSString stringWithFormat:@"%02x%02x%02x", [self byteAt:1], [self byteAt:2], [self byteAt:3]];
}

@end
