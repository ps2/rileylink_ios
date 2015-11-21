//
//  PHEChangeSensorSetup2.m
//

#import "PHEChangeSensorSetup2.h"

@implementation PHEChangeSensorSetup2

+ (int) eventTypeCode {
  return 0x50;
}


- (int) length {
  if (self.pumpModel.hasLowSuspend) {
    return 41;
  } else {
    return 37;
  }
}

@end
