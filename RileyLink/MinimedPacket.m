//
//  MinimedPacket.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import "MinimedPacket.h"
#import "NSData+Conversion.h"

static const unsigned char crcTable[256] = { 0x0, 0x9B, 0xAD, 0x36, 0xC1, 0x5A, 0x6C, 0xF7, 0x19, 0x82, 0xB4, 0x2F, 0xD8, 0x43, 0x75, 0xEE, 0x32, 0xA9, 0x9F, 0x4, 0xF3, 0x68, 0x5E, 0xC5, 0x2B, 0xB0, 0x86, 0x1D, 0xEA, 0x71, 0x47, 0xDC, 0x64, 0xFF, 0xC9, 0x52, 0xA5, 0x3E, 0x8, 0x93, 0x7D, 0xE6, 0xD0, 0x4B, 0xBC, 0x27, 0x11, 0x8A, 0x56, 0xCD, 0xFB, 0x60, 0x97, 0xC, 0x3A, 0xA1, 0x4F, 0xD4, 0xE2, 0x79, 0x8E, 0x15, 0x23, 0xB8, 0xC8, 0x53, 0x65, 0xFE, 0x9, 0x92, 0xA4, 0x3F, 0xD1, 0x4A, 0x7C, 0xE7, 0x10, 0x8B, 0xBD, 0x26, 0xFA, 0x61, 0x57, 0xCC, 0x3B, 0xA0, 0x96, 0xD, 0xE3, 0x78, 0x4E, 0xD5, 0x22, 0xB9, 0x8F, 0x14, 0xAC, 0x37, 0x1, 0x9A, 0x6D, 0xF6, 0xC0, 0x5B, 0xB5, 0x2E, 0x18, 0x83, 0x74, 0xEF, 0xD9, 0x42, 0x9E, 0x5, 0x33, 0xA8, 0x5F, 0xC4, 0xF2, 0x69, 0x87, 0x1C, 0x2A, 0xB1, 0x46, 0xDD, 0xEB, 0x70, 0xB, 0x90, 0xA6, 0x3D, 0xCA, 0x51, 0x67, 0xFC, 0x12, 0x89, 0xBF, 0x24, 0xD3, 0x48, 0x7E, 0xE5, 0x39, 0xA2, 0x94, 0xF, 0xF8, 0x63, 0x55, 0xCE, 0x20, 0xBB, 0x8D, 0x16, 0xE1, 0x7A, 0x4C, 0xD7, 0x6F, 0xF4, 0xC2, 0x59, 0xAE, 0x35, 0x3, 0x98, 0x76, 0xED, 0xDB, 0x40, 0xB7, 0x2C, 0x1A, 0x81, 0x5D, 0xC6, 0xF0, 0x6B, 0x9C, 0x7, 0x31, 0xAA, 0x44, 0xDF, 0xE9, 0x72, 0x85, 0x1E, 0x28, 0xB3, 0xC3, 0x58, 0x6E, 0xF5, 0x2, 0x99, 0xAF, 0x34, 0xDA, 0x41, 0x77, 0xEC, 0x1B, 0x80, 0xB6, 0x2D, 0xF1, 0x6A, 0x5C, 0xC7, 0x30, 0xAB, 0x9D, 0x6, 0xE8, 0x73, 0x45, 0xDE, 0x29, 0xB2, 0x84, 0x1F, 0xA7, 0x3C, 0xA, 0x91, 0x66, 0xFD, 0xCB, 0x50, 0xBE, 0x25, 0x13, 0x88, 0x7F, 0xE4, 0xD2, 0x49, 0x95, 0xE, 0x38, 0xA3, 0x54, 0xCF, 0xF9, 0x62, 0x8C, 0x17, 0x21, 0xBA, 0x4D, 0xD6, 0xE0, 0x7B };

static const unsigned short crc16Table[256] = { 0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef, 0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6, 0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de, 0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485, 0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d, 0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4, 0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc, 0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823, 0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b, 0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12, 0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a, 0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41, 0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49, 0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70, 0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78, 0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f, 0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067, 0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e, 0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256, 0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d, 0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c, 0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634, 0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab, 0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3, 0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a, 0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92, 0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9, 0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1, 0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8, 0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0 };

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

+ (unsigned char) crcForData:(NSData*)data {
  unsigned char crc = 0;
  const unsigned char *pdata = data.bytes;
  unsigned long nbytes = data.length;
  /* loop over the buffer data */
  while (nbytes-- > 0) {
    crc = crcTable[(crc ^ *pdata++) & 0xff];
  }
  return crc;
}

+ (unsigned short) crc16ForData:(NSData*)data {
  unsigned short crc = 0xffff;
  const unsigned char *pdata = data.bytes;
  unsigned long nbytes = data.length;
  /* loop over the buffer data */
  while (nbytes-- > 0) {
    unsigned char b = *pdata++;
    crc = ((crc << 8) ^ crc16Table[((crc >> 8) ^ b) & 0xff]) & 0xffff;
  }
  return crc;
}


- (BOOL) crcValid {
  unsigned char crc = 0;
  const unsigned char *pdata = _data.bytes;
  unsigned long nbytes = _data.length-1;
  const unsigned char packetCrc = pdata[nbytes];
  /* loop over the buffer data */
  while (nbytes-- > 0) {
    crc = crcTable[(crc ^ *pdata++) & 0xff];
  }
  //printf("crc = 0x%x, last_byte=0x%x\n", crc, packetCrc);
  return crc == packetCrc;
}

- (BOOL) isValid {
  return _data.length > 0 && [self crcValid];
}

+ (NSData*)encodeData:(NSData*)data {
  NSMutableData *outData = [NSMutableData data];
  char codes[16] = {21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28};
  const unsigned char *inBytes = [data bytes];
  unsigned int acc = 0x0;
  int bitcount = 0;
  for (int i=0; i < data.length; i++) {
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

+ (NSData*)encodeAndCRC8Data:(NSData*)data {
  NSMutableData *dataPlusCrc = [data mutableCopy];
  unsigned char crc = [MinimedPacket crcForData:data];
  [dataPlusCrc appendBytes:&crc length:1];
  return [self encodeData:dataPlusCrc];
}

+ (NSData*)encodeAndCRC16Data:(NSData*)data {
  NSMutableData *dataPlusCrc = [data mutableCopy];
  unsigned short crc = [MinimedPacket crc16ForData:data];
  unsigned char crcBytes[2];
  crcBytes[0] = crc >> 8;
  crcBytes[1] = crc & 0xff;
  [dataPlusCrc appendBytes:crcBytes length:2];
  return [self encodeData:dataPlusCrc];
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
