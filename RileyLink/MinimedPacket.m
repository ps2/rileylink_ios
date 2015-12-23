//
//  MinimedPacket.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import "MinimedPacket.h"
#import "NSData+Conversion.h"
#import "CRC8.h"


@interface MinimedPacket ()

@property (nonatomic, assign) NSInteger codingErrorCount;

@end

@implementation MinimedPacket

+ (void)initialize {
}

- (instancetype)init NS_UNAVAILABLE
{
    return nil;
}

- (instancetype)initWithData:(NSData*)data
{
  self = [super init];
  if (self) {
    _codingErrorCount = 0;
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
      //_data = [self decodeRFEncoding:data]; // cc1110 is doing decoding now
      _data = [data subdataWithRange:NSMakeRange(2, data.length - 2)];
      //NSLog(@"New packet: %@", [data hexadecimalString]);
    }
  }
  return self;
}


- (BOOL) crcValid {
  if (_data.length < 2) {
    return NO;
  }
  uint8_t packetCrc = ((uint8_t*)[_data bytes])[_data.length-1];
  uint8_t crc = [CRC8 compute:[_data subdataWithRange:NSMakeRange(0, _data.length-1)]];
  return crc == packetCrc;
}

- (BOOL) isValid {
  return _data.length > 0 && [self crcValid];
}

+ (NSData*)encodeData:(NSData*)data {
  NSMutableData *outData = [NSMutableData data];
  NSMutableData *dataPlusCrc = [data mutableCopy];
  unsigned char crc = [CRC8 compute:data];
  [dataPlusCrc appendBytes:&crc length:1];
  char codes[16] = {21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28};
  const unsigned char *inBytes = [dataPlusCrc bytes];
  unsigned int acc = 0x0;
  int bitcount = 0;
  for (int i=0; i < dataPlusCrc.length; i++) {
    acc <<= 6;
    acc |= codes[inBytes[i] >> 4];
    bitcount += 6;
    
    acc <<= 6;
    acc |= codes[inBytes[i] & 0x0f];
    bitcount += 6;
    
    while (bitcount >= 8) {
      unsigned char outByte = acc >> (bitcount-8) & 0xff;
      [outData appendBytes:&outByte length:1];
      bitcount -= 8;
      acc &= (0xffff >> (16-bitcount));
    }
  }
  if (bitcount > 0) {
    acc <<= (8-bitcount);
    unsigned char outByte = acc & 0xff;
    [outData appendBytes:&outByte length:1];
  }
  return outData;
}

- (NSData*)decodeRF:(NSData*) rawData {
  // Converted from ruby using: CODE_SYMBOLS.each{|k,v| puts "@#{Integer("0b"+k)}: @#{Integer("0x"+v)},"};nil
  NSDictionary *codes = @{@21: @0,
                          @49: @1,
                          @50: @2,
                          @35: @3,
                          @52: @4,
                          @37: @5,
                          @38: @6,
                          @22: @7,
                          @26: @8,
                          @25: @9,
                          @42: @10,
                          @11: @11,
                          @44: @12,
                          @13: @13,
                          @14: @14,
                          @28: @15};
  NSMutableData *output = [NSMutableData data];
  const unsigned char *bytes = [rawData bytes];
  int availBits = 0;
  unsigned int x = 0;
  for (int i = 0; i < [rawData length]; i++)
  {
    x = (x << 8) + bytes[i];
    availBits += 8;
    if (availBits >= 12) {
      NSNumber *hiNibble = codes[@(x >> (availBits - 6))];
      NSNumber *loNibble = codes[@((x >> (availBits - 12)) & 0b111111)];
      if (hiNibble && loNibble) {
        unsigned char decoded = ([hiNibble integerValue] << 4) + [loNibble integerValue];
        [output appendBytes:&decoded length:1];
      } else {
        _codingErrorCount += 1;
      }
      availBits -= 12;
      x = x & (0xffff >> (16-availBits));
    }
  }
  return output;
}

- (NSString*) hexadecimalString {
  return [_data hexadecimalString];
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
