//
//  PHEBolusNormal.m
//

#import "PHEBolusNormal.h"

@implementation PHEBolusNormal

+ (int) eventTypeCode {
  return 0x01;
}

- (instancetype)initWithData:(NSData*)data andPumpModel:(PumpModel*)model
{
  self = [super initWithData:data andPumpModel:model];
  if (self) {
    if (data.length >= self.length) {
      if (model.larger) {
        _amount = [self insulinDecodeWithBytesA:[self byteAt:3] andB:[self byteAt:4]];
        _programmed_amount = [self insulinDecodeWithBytesA:[self byteAt:1] andB:[self byteAt:2]];
        _unabsorbed_insulin_total = [self insulinDecodeWithBytesA:[self byteAt:5] andB:[self byteAt:6]];
        _duration = [self byteAt:7] * 30;
      } else {
        _amount = [self byteAt:2] / 10.0;
        _programmed_amount = [self byteAt:1] / 10.0;
        _duration = [self byteAt:3] * 30;
      }
    }
  }
  return self;
}

- (double) insulinDecodeWithBytesA:(uint8_t)a andB:(uint8_t)b {
  return ((a << 8) + b) / 40.0;
}


- (int) length {
  if (self.pumpModel.larger) {
    return 13;
  } else {
    return 9;
  }
}

- (NSDateComponents*) timestamp {
  if (self.pumpModel.larger) {
    return [self parseDateComponents:8];
  } else {
    return [self parseDateComponents:4];
  }
}

- (NSString*) description {
  return [NSString stringWithFormat:@"%@ - %@ amount:%f programmed:%f unabsorbed:%f duration:%ld",
          self.class, self.timestampStr, self.amount, self.programmed_amount, self.unabsorbed_insulin_total, (long)self.duration];
}


@end
