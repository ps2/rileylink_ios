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

@end
