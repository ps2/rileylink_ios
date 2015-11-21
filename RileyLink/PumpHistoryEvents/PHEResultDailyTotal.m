//
//  PHEResultDailyTotal.m
//

#import "PHEResultDailyTotal.h"

@implementation PHEResultDailyTotal

+ (int) eventTypeCode {
  return 0x07;
}


- (int) length {
  if (self.pumpModel.larger) {
    return 10;
  } else {
    return 7;
  }  
}

@end
