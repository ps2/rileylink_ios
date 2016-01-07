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

//- (NSDateComponents*) validDate {
//  [self parseDate2Byte:5];
//}

- (NSDateComponents*) timestamp {
  NSDateComponents *c = [self parseDate2Byte:5];
  
  NSCalendar *cal = [NSCalendar currentCalendar];
  [cal setTimeZone:[NSTimeZone localTimeZone]];
  [cal setLocale:[NSLocale currentLocale]];
  NSDate *date = [cal dateFromComponents:c];
  
  NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
  dayComponent.day = 1;
  
  NSDate *nextDate = [cal dateByAddingComponents:dayComponent toDate:date options:0];

  return [cal components:0 fromDate:nextDate];
}


@end
