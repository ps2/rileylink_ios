//
//  PHEClearAlarm.m
//

#import "PHEClearAlarm.h"

@implementation PHEClearAlarm

+ (int) eventTypeCode {
  return 0x0c;
}


- (int) length {
  return 7;
}

@end
