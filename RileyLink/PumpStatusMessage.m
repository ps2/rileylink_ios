//
//  GlucoseSensorMessage.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 8/14/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import "PumpStatusMessage.h"


@interface PumpStatusMessage ()

@end

@implementation PumpStatusMessage

- (instancetype)initWithData:(NSData*)data
{
  self = [super initWithData:data];
  if (self) {
    self.data = [data subdataWithRange:NSMakeRange(5, data.length-6)];
  }
  return self;
}

- (NSDictionary*) bitBlocks {
  return @{@"sequence":          @[@1, @7],
           @"trend":             @[@12, @3],
           @"pump_hour":         @[@19, @5],
           @"pump_minute":       @[@26, @6],
           @"pump_second":       @[@34, @6],
           @"pump_year":         @[@40, @8],
           @"pump_month":        @[@52, @4],
           @"pump_day":          @[@59, @5],
           @"bg_h":              @[@72, @8],
           @"prev_bg_h":         @[@80, @8],
           @"insulin_remaining": @[@101,@11],
           @"batt":              @[@116,@4],
           @"sensor_age":        @[@144,@8],
           @"sensor_remaining":  @[@152,@8],
           @"next_cal_hour":     @[@160,@8], // ff at sensor end, 00 at sensor off
           @"next_cal_minute":   @[@168,@8],
           @"active_ins":        @[@181, @11],
           @"prev_bg_l":         @[@198, @1],
           @"bg_l":              @[@199, @1],
           @"sensor_hour":       @[@227, @5],
           @"sensor_minute":     @[@234, @6],
           @"sensor_year":       @[@248, @8],
           @"sensor_month":      @[@260, @4],
           @"sensor_day":        @[@267, @5],
  };
}

- (NSDate*) nextCal {
  NSInteger hour = [self getBits:@"next_cal_hour"];
  NSInteger minute = [self getBits:@"next_cal_minute"];
  
  NSDate *pumpDate = [self pumpTime];
  
  return [[NSCalendar currentCalendar] nextDateAfterDate:pumpDate matchingHour:hour minute:minute second:0 options:NSCalendarMatchNextTime];
}

- (NSInteger) sensorAge {
  return [self getBits:@"sensor_age"];
}

- (NSInteger) sensorRemaining {
  return [self getBits:@"sensor_remaining"];
}

- (NSInteger) batteryPct {
  return [self getBits:@"batt"] / 4.0 * 100;
}

- (SensorStatus) sensorStatus {
  NSInteger bgH = [self getBits:@"bg_h"];
  switch (bgH) {
    case 0:
      return SENSOR_STATUS_MISSING;
    case 1:
      return SENSOR_STATUS_METER_BG_NOW;
    case 2:
      return SENSOR_STATUS_WEAK_SIGNAL;
    case 4:
      return SENSOR_STATUS_WARMUP;
    case 7:
      return SENSOR_STATUS_HIGH_BG;
    case 10:
      return SENSOR_STATUS_LOST;
  }
  if (bgH > 10) {
    return SENSOR_STATUS_OK;
  } else {
    return SENSOR_STATUS_UNKNOWN;
  }
}

- (NSString*) sensorStatusString {
  switch ([self sensorStatus]) {
    case SENSOR_STATUS_MISSING:
      return @"Sensor Missing";
    case SENSOR_STATUS_METER_BG_NOW:
      return @"Meter BG Now";
    case SENSOR_STATUS_WEAK_SIGNAL:
      return @"Weak Signal";
    case SENSOR_STATUS_WARMUP:
      return @"Warmup";
    case SENSOR_STATUS_HIGH_BG:
      return @"High BG";
    case SENSOR_STATUS_LOST:
      return @"Sensor Lost";
    case SENSOR_STATUS_OK:
      return @"Sensor OK";
    case SENSOR_STATUS_UNKNOWN:
    default:
      return @"Sensor Status Unknown";
  }
}

- (GlucoseTrend) trend {
  return (GlucoseTrend)[self getBits:@"trend"];
}

- (NSInteger) glucose {
  if ([self sensorStatus] == SENSOR_STATUS_OK) {
    return ([self getBits:@"bg_h"] << 1) + [self getBits:@"bg_l"];
  } else {
    return 0;
  }
}

- (NSInteger) previousGlucose {
  if ([self sensorStatus] == SENSOR_STATUS_OK) {
    return ([self getBits:@"prev_bg_h"] << 1) + [self getBits:@"prev_bg_l"];
  } else {
    return 0;
  }
}

- (double) activeInsulin {
  return [self getBits:@"active_ins"] * 0.025;
}

- (double) insulinRemaining {
  return [self getBits:@"insulin_remaining"] / 10.0;
}
                                                 
- (NSDate*) pumpTime {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [[NSDateComponents alloc] init];
  [components setYear:[self getBits:@"pump_year"]+2000];
  [components setMonth:[self getBits:@"pump_month"]];
  [components setDay:[self getBits:@"pump_day"]];
  [components setHour:[self getBits:@"pump_hour"]];
  [components setMinute:[self getBits:@"pump_minute"]];
  [components setSecond:0];
  return [calendar dateFromComponents:components];
}


- (NSDate*) measurementTime {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [[NSDateComponents alloc] init];
  [components setYear:[self getBits:@"sensor_year"]+2000];
  [components setMonth:[self getBits:@"sensor_month"]];
  [components setDay:[self getBits:@"sensor_day"]];
  [components setHour:[self getBits:@"sensor_hour"]];
  [components setMinute:[self getBits:@"sensor_minute"]];
  [components setSecond:0];
  return [calendar dateFromComponents:components];
}

@end
