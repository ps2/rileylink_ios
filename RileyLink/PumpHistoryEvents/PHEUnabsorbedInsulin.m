//
//  PHEUnabsorbedInsulin.m
//

#import "PHEUnabsorbedInsulin.h"

@implementation PHEUnabsorbedInsulin

+ (int) eventTypeCode {
  return 0x5c;
}

- (int) length {
  return MAX([self byteAt:1], 2);
}

- (nullable NSDateComponents*) timestamp {
  return nil;
}


@end
