//
//  PHEDeleteAlarmClockTime.m
//

#import "PHEDeleteAlarmClockTime.h"

@implementation PHEDeleteAlarmClockTime

+ (int) eventTypeCode {
  return 0x6a;
}


- (int) length {
  return 14;
}

@end
