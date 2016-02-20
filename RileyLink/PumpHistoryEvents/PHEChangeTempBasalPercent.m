//
//  PHEChangeTempBasalPercent.m
//

#import "PHEChangeTempBasalPercent.h"

@implementation PHEChangeTempBasalPercent

+ (int) eventTypeCode {
  return 0x33;
}


- (int) length {
  return 15;
}

@end
