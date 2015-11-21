//
//  PHEChangeCaptureEventEnable.m
//

#import "PHEChangeCaptureEventEnable.h"

@implementation PHEChangeCaptureEventEnable

+ (int) eventTypeCode {
  return 0x83;
}


- (int) length {
  return 7;
}

@end
