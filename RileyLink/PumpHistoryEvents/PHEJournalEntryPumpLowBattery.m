//
//  PHEJournalEntryPumpLowBattery.m
//

#import "PHEJournalEntryPumpLowBattery.h"

@implementation PHEJournalEntryPumpLowBattery

+ (int) eventTypeCode {
  return 0x19;
}


- (int) length {
  return 7;
}

@end
