//
//  PHEAlarmSensor.m
//

#import "PHEAlarmSensor.h"

@implementation PHEAlarmSensor

+ (int) eventTypeCode {
  return 0x0b;
}

- (int) length {
  return 8;
}

- (NSString*) alarmTypeStr {
  NSString *str = @{
    @101: @"High Glucose",
    @102: @"Low Glucose",
    @104: @"Meter BG Now",
    @105: @"Cal Reminder",
    @106: @"Calibration Error",
    @107: @"Sensor End",
    @112: @"Weak Signal",
    @113: @"Lost Sensor",
    @114: @"High Glucose Predicted",
    @115: @"Low Glucose Predicted"
    }[[NSNumber numberWithInt:[self alarmType]]];
  if (str == nil) {
    str = [NSString stringWithFormat:@"Unknown(0x%02x)", [self alarmType]];
  }
  return str;  
}

- (uint8_t) alarmType {
  return [self byteAt:1];
}

- (int) amount {
  return (([self byteAt:7] & 0b10000000) << 1) + [self byteAt:2];
}

- (int) profileIndex {
  return [self byteAt:1];
}

- (NSDateComponents*) timestamp {
  return [self parseDateComponents:3];
}

- (NSDictionary*) asJSON {
  NSMutableDictionary *base = [[super asJSON] mutableCopy];
  [base addEntriesFromDictionary:@{
                                   @"alarm_description": [self alarmTypeStr],
                                   @"alarm_type": @([self alarmType])
                                   }];
  if ([self amount] > 0) {
    base[@"amount"] = [NSNumber numberWithInt:[self alarmType]];
  }
  return base;
}


@end
