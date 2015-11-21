//
//  PHEBolusWizardBolusEstimate.m
//

#import "PHEBolusWizardBolusEstimate.h"

@implementation PHEBolusWizardBolusEstimate

+ (int) eventTypeCode {
  return 0x5b;
}

- (int) length {
  if (self.pumpModel.larger) {
    return 22;
  } else {
    return 20;
  }
}

- (int) insulinDecodeByteA:(uint8_t)a byteB:(uint8_t)b {
  return ((a << 8) + b) / 40.0;
}

- (int) carbohydrates {
  return (([self byteAt:8] & 0xc) << 6) + [self byteAt:7];
}

- (int) bloodGlucose {
  return (([self byteAt:8] & 0x3) << 8) + [self byteAt:1];
}

- (int) foodEstimate {
  return [self insulinDecodeByteA:[self byteAt:14] byteB:[self byteAt:15]];
}

- (int) correctionEstimate {
  return ((([self byteAt:16] & 0x38) << 5) + [self byteAt:13]) / 40.0;
}

- (int) bolusEstimate {
  return [self insulinDecodeByteA:[self byteAt:19] byteB:[self byteAt:20]];
}

- (int) unabsorbedInsulinTotal {
  return [self insulinDecodeByteA:[self byteAt:17] byteB:[self byteAt:18]];
}

- (int) bgTargetLow {
  return [self byteAt:12];
}

- (int) bgTargetHigh {
  return [self byteAt:21];
}

- (int) insulinSensitivity {
  return [self byteAt:11];
}

- (int) carbRatio {
  return (([self byteAt:9] & 0x7) << 8) + [self byteAt:10] / 10.0;
}

@end
