//
//  PHEAlarmClockReminder.m
//

#import "PHEAlarmClockReminder.h"

@implementation PHEAlarmClockReminder

+ (int) eventTypeCode {
  return 0x35;
}


- (int) length {
  return 7;
}

@end
