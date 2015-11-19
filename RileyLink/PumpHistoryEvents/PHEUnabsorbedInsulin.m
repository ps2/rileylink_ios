//
//  PHEUnabsorbedInsulin.m
//

#import "PHEUnabsorbedInsulin.h"

@implementation PHEUnabsorbedInsulin

+ (int) eventTypeCode {
  return 0x5c;
}


- (int) length {
  return [self byteAt:0];
}

@end
