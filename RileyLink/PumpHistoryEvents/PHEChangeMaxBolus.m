//
//  PHEChangeMaxBolus.m
//

#import "PHEChangeMaxBolus.h"

@implementation PHEChangeMaxBolus

+ (int) eventTypeCode {
  return 0x24;
}


- (int) length {
  return 7;
}

@end
