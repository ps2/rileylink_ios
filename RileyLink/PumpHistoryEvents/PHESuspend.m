//
//  PHESuspend.m
//

#import "PHESuspend.h"

@implementation PHESuspend

+ (int) eventTypeCode {
  return 0x1e;
}


- (int) length {
  return 7;
}

@end
