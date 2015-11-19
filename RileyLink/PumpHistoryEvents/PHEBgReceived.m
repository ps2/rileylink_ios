//
//  PHEBgReceived.m
//

#import "PHEBgReceived.h"

@implementation PHEBgReceived

+ (int) eventTypeCode {
  return 0x3f;
}


- (int) length {
  return 10;
}

@end
