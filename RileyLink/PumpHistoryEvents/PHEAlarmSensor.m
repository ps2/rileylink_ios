//
//  PHEAlarmSensor.m
//

#import "PHEAlarmSensor.h"

@implementation PHEAlarmSensor

+ (int) eventTypeCode {
  return 0x0b;
}


- (int) length {
  return 8;
}

@end
