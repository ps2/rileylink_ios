//
//  PHEJournalEntryPumpLowReservoir.m
//

#import "PHEJournalEntryPumpLowReservoir.h"

@implementation PHEJournalEntryPumpLowReservoir

+ (int) eventTypeCode {
  return 0x34;
}


- (int) length {
  return 7;
}

@end
