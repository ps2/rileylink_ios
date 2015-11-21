//
//  PHEBolusNormal.m
//

#import "PHEBolusNormal.h"

@implementation PHEBolusNormal

+ (int) eventTypeCode {
  return 0x01;
}

- (int) length {
  if (self.pumpModel.larger) {
    return 13;
  } else {
    return 9;
  }
}

- (NSDateComponents*) timestamp {
  return [self parseDateComponents:8];
}

@end
