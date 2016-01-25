//
//  PHEChangeBolusReminderEnable.m
//

#import "PHEChangeBolusReminderEnable.h"

@implementation PHEChangeBolusReminderEnable

+ (int) eventTypeCode {
  return 0x66;
}


- (int) length {
  return 7;
}

@end
