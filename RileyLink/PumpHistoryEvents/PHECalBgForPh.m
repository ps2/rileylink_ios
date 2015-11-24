//
//  PHECalBgForPh.m
//

#import "PHECalBgForPh.h"

@implementation PHECalBgForPh

+ (int) eventTypeCode {
  return 0x0a;
}

- (int) amount {
  return (([self byteAt:6] & 0b10000000) << 1) + [self byteAt:1];
}

- (int) length {
  return 7;
}

- (NSDictionary*) asJSON {
  NSMutableDictionary *base = [[super asJSON] mutableCopy];
  if ([self amount] > 0) {
    base[@"amount"] = [NSNumber numberWithInt:[self amount]];
  }
  return base;
}

@end
