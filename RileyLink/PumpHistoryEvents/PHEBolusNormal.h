//
//  PHEBolusNormal.h
//

#import <Foundation/Foundation.h>
#import "PumpHistoryEventBase.h"

@interface PHEBolusNormal : PumpHistoryEventBase

@property (nonatomic, readonly) double amount;
@property (nonatomic, readonly) double programmed_amount;
@property (nonatomic, readonly) double unabsorbed_insulin_total;
@property (nonatomic, readonly) NSInteger duration;

@end
