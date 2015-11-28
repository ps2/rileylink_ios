//
//  PHEBolusWizardBolusEstimate.m
//

#import "PHEBolusWizardBolusEstimate.h"

@implementation PHEBolusWizardBolusEstimate

+ (int) eventTypeCode {
  return 0x5b;
}

- (instancetype)initWithData:(NSData*)data andPumpModel:(PumpModel*)model
{
  self = [super initWithData:data andPumpModel:model];
  if (self) {
    if (data.length >= self.length) {
      if (model.larger) {
        _carbohydrates = (([self byteAt:8] & 0xc) << 6) + [self byteAt:7];
        _bloodGlucose = (([self byteAt:8] & 0x3) << 8) + [self byteAt:1];
        _foodEstimate = [self insulinDecodeByteA:[self byteAt:14] byteB:[self byteAt:15]];
        _correctionEstimate = ((([self byteAt:16] & 0b111000) << 5) + [self byteAt:13]) / 40.0;
        _bolusEstimate = [self insulinDecodeByteA:[self byteAt:19] byteB:[self byteAt:20]];
        _unabsorbedInsulinTotal = [self insulinDecodeByteA:[self byteAt:17] byteB:[self byteAt:18]];
        _bgTargetLow = [self byteAt:12];
        _bgTargetHigh = [self byteAt:21];
        _insulinSensitivity = [self byteAt:11];
        _carbRatio = (([self byteAt:9] & 0x7) << 8) + [self byteAt:10] / 10.0;
      } else {
        _carbohydrates = [self byteAt:7];
        _bloodGlucose = (([self byteAt:8] & 0x3) << 8) + [self byteAt:1];
        _foodEstimate = [self byteAt:13]/10.0;
        _correctionEstimate = (([self byteAt:14] << 8) + [self byteAt:12]) / 10.0;
        _bolusEstimate = [self byteAt:18]/10.0;
        _unabsorbedInsulinTotal = [self byteAt:16]/10.0;
        _bgTargetLow = [self byteAt:11];
        _bgTargetHigh = [self byteAt:19];
        _insulinSensitivity = [self byteAt:10];
        _carbRatio = [self byteAt:9];
      }
    }
  }
  return self;
}

- (double) insulinDecodeByteA:(uint8_t)a byteB:(uint8_t)b {
  return ((a << 8) + b) / 40.0;
}

- (int) length {
  if (self.pumpModel.larger) {
    return 22;
  } else {
    return 20;
  }
}


- (NSDictionary*) asJSON {
  NSMutableDictionary *base = [[super asJSON] mutableCopy];
  [base addEntriesFromDictionary:@{
                                   @"bg_target_high": @(self.bgTargetHigh),
                                   @"correction_estimate": @(self.correctionEstimate),
                                   @"unabsorbed_insulin_total": @(self.unabsorbedInsulinTotal),
                                   @"bolus_estimate": @(self.bolusEstimate),
                                   @"carb_ratio": @(self.carbRatio),
                                   @"food_estimate": @(self.foodEstimate),
                                   @"bg_target_low": @(self.bgTargetLow),
                                   @"sensitivity": @(self.insulinSensitivity),
                                   }];
  if (self.bloodGlucose > 0) {
    base[@"bg"] = @(self.bloodGlucose);
  }
  if (self.carbohydrates > 0) {
    base[@"carb_input"] = @(self.carbohydrates);
  }
  
  return base;
}


@end
