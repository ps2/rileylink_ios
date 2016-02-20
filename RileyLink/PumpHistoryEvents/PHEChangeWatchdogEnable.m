//
//  PHEChangeWatchdogEnable.m
//

#import "PHEChangeWatchdogEnable.h"

@implementation PHEChangeWatchdogEnable

+ (int) eventTypeCode {
  return 0x7c;
}


- (int) length {
  return 7;
}

@end
