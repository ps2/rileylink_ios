//
//  PHESara6E.m
//

#import "PHESara6E.h"

@implementation PHESara6E

+ (int) eventTypeCode {
  return 0x6e;
}


- (int) length {
  return 52;
}

- (NSDateComponents*) timestamp {
  return [self parseDate2Byte:1];
}

@end
