//
//  PHEChangeAlarmClockTime.m
//

#import "PHEChangeAlarmClockTime.h"

@implementation PHEChangeAlarmClockTime

+ (int) eventTypeCode {
  return 0x32;
}


- (int) length {
  return 14;
}

@end
