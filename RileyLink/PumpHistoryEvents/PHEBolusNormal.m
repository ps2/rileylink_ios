//
//  PHEBolusNormal.m
//

#import "PHEBolusNormal.h"

@implementation PHEBolusNormal

+ (int) eventTypeCode {
  return 0x01;
}


- (int) length {
  return 13;
}

@end
