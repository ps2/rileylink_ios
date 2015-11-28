//
//  PHEBolusWizardBolusEstimate.h
//

#import <Foundation/Foundation.h>
#import "PumpHistoryEventBase.h"

@interface PHEBolusWizardBolusEstimate : PumpHistoryEventBase

@property (nonatomic, readonly) int carbohydrates;
@property (nonatomic, readonly) int bloodGlucose;
@property (nonatomic, readonly) double foodEstimate;
@property (nonatomic, readonly) double correctionEstimate;
@property (nonatomic, readonly) double bolusEstimate;
@property (nonatomic, readonly) double unabsorbedInsulinTotal;
@property (nonatomic, readonly) int bgTargetLow;
@property (nonatomic, readonly) int bgTargetHigh;
@property (nonatomic, readonly) int insulinSensitivity;
@property (nonatomic, readonly) double carbRatio;


@end
