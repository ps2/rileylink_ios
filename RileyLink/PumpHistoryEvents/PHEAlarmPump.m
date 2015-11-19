//
//  PHEAlarmPump.m
//

#import "PHEAlarmPump.h"

@implementation PHEAlarmPump

+ (int) eventTypeCode {
  return 0x06;
}

- (int) length {
  return 9;
}

- (NSDateComponents*) timestamp {
  return [self parseDateComponents:4];
}


@end
