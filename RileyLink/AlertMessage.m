//
//  AlertMessage.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/16/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "AlertMessage.h"

@implementation AlertMessage

- (NSDictionary*) bitBlocks {
  return @{@"sequence":          @[@41, @7],
           @"alert_type":        @[@48, @8],
           @"alert_hour":        @[@59, @5],
           @"alert_minute":      @[@66, @6],
           @"alert_second":      @[@74, @6],
           @"alert_year":        @[@80, @8],
           @"alert_month":       @[@92, @4],
           @"alert_day":         @[@99, @5],
           };
}

- (NSDate*) timestamp {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [[NSDateComponents alloc] init];
  [components setYear:[self getBits:@"alert_year"]+2000];
  [components setMonth:[self getBits:@"alert_month"]];
  [components setDay:[self getBits:@"alert_day"]];
  [components setHour:[self getBits:@"alert_hour"]];
  [components setMinute:[self getBits:@"alert_minute"]];
  [components setSecond:0];
  return [calendar dateFromComponents:components];
}

- (AlertType) alertType {
  return (AlertType)[self getBits:@"alert_type"];
}

- (NSString*) alertTypeStr {
  switch (self.alertType) {
    case ALERT_TYPE_NO_DELIVERY:
      return @"No Delivery";
      break;
    case ALERT_TYPE_MAX_HOURLY_BOLUS:
      return @"Max Hourly Bolus";
      break;
    case ALERT_TYPE_MAX_LOW_RESERVOIR:
      return @"Low Reservoir";
      break;
    case ALERT_TYPE_HIGH_GLUCOSE:
      return @"High Glucose";
      break;
    case ALERT_TYPE_LOW_GLUCOSE:
      return @"Low Glucose";
      break;
    case ALERT_TYPE_METER_BG_NOW:
      return @"Meter BG Now";
      break;
    case ALERT_TYPE_METER_BG_SOON:
      return @"Meter BG Soon";
      break;
    case ALERT_TYPE_CALIBRATION_ERROR:
      return @"Calibration Error";
      break;
    case ALERT_TYPE_SENSOR_END:
      return @"Sensor End";
      break;
    case ALERT_TYPE_WEAK_SIGNAL:
      return @"Weak Signal";
      break;
    case ALERT_TYPE_LOST_SENSOR:
      return @"Lost Sensor";
      break;
    case ALERT_TYPE_HIGH_PREDICTED:
      return @"High Predicted";
      break;
    case ALERT_TYPE_LOW_PREDICTED:
      return @"Low Predicted";
      break;
    default:
      return @"Unknown";
      break;
  }
}


@end
