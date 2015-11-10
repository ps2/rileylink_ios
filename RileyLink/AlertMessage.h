//
//  AlertMessage.h
//  RileyLink
//
//  Created by Pete Schwamb on 10/16/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "MessageBase.h"

@interface AlertMessage : MessageBase

typedef NS_ENUM(unsigned int, AlertType) {
		ALERT_TYPE_NO_DELIVERY = 0x04,
		ALERT_TYPE_MAX_HOURLY_BOLUS = 0x33,
		ALERT_TYPE_MAX_LOW_RESERVOIR = 0x52,
		ALERT_TYPE_HIGH_GLUCOSE = 0x65,
		ALERT_TYPE_LOW_GLUCOSE = 0x66,
		ALERT_TYPE_METER_BG_NOW = 0x68,
		ALERT_TYPE_METER_BG_SOON = 0x69,
		ALERT_TYPE_CALIBRATION_ERROR = 0x6a,
		ALERT_TYPE_SENSOR_END = 0x6b,
		ALERT_TYPE_WEAK_SIGNAL = 0x70,
		ALERT_TYPE_LOST_SENSOR = 0x71,
		ALERT_TYPE_HIGH_PREDICTED = 0x72,
		ALERT_TYPE_LOW_PREDICTED = 0x73,
};

- (NSDate*) timestamp;
- (AlertType) alertType;
- (NSString*) alertTypeStr;



@end
