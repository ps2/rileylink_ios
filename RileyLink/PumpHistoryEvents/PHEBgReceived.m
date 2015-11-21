//
//  PHEBgReceived.m
//

#import "PHEBgReceived.h"
#import "NSData+Conversion.h"

@implementation PHEBgReceived

+ (int) eventTypeCode {
  return 0x3f;
}

- (int) length {
  return 10;
}

- (int) bloodGlucose {
  return ([self byteAt:1] << 3) + ([self byteAt:4] >> 5);
}

- (NSString*) meterId {
  return [[self.data subdataWithRange:NSMakeRange(7, 3)] hexadecimalString];
}

@end
