//
//  PHEEnableDisableRemote.m
//

#import "PHEEnableDisableRemote.h"

@implementation PHEEnableDisableRemote

+ (int) eventTypeCode {
  return 0x26;
}


- (int) length {
  return 21;
}

@end
