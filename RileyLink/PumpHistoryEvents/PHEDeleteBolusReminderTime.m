//
//  PHEDeleteBolusReminderTime.m
//

#import "PHEDeleteBolusReminderTime.h"

@implementation PHEDeleteBolusReminderTime

+ (int) eventTypeCode {
  return 0x68;
}


- (int) length {
  return 9;
}

@end
