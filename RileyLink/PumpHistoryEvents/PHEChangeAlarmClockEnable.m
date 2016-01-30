//
//  PHEChangeAlarmClockEnable.m
//

#import "PHEChangeAlarmClockEnable.h"

@implementation PHEChangeAlarmClockEnable

+ (int) eventTypeCode {
  return 0x61;
}


- (int) length {
  return 7;
}

@end
