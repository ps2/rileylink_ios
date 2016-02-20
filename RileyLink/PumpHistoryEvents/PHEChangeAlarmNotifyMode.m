//
//  PHEChangeAlarmNotifyMode.m
//

#import "PHEChangeAlarmNotifyMode.h"

@implementation PHEChangeAlarmNotifyMode

+ (int) eventTypeCode {
  return 0x63;
}


- (int) length {
  return 7;
}

@end
