//
//  PHEChangeSensorRateOfChangeAlertSetup.m
//

#import "PHEChangeSensorRateOfChangeAlertSetup.h"

@implementation PHEChangeSensorRateOfChangeAlertSetup

+ (int) eventTypeCode {
  return 0x56;
}


- (int) length {
  return 12;
}

@end
