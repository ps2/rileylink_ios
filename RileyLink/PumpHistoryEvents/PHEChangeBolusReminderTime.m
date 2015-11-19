//
//  PHEChangeBolusReminderTime.m
//

#import "PHEChangeBolusReminderTime.h"

@implementation PHEChangeBolusReminderTime

+ (int) eventTypeCode {
  return 0x67;
}


- (int) length {
  return 9;
}

@end
