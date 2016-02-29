//
//  PumpHistoryEventBase.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpHistoryEventBase.h"
#import "NSData+Conversion.h"
#import "ISO8601DateFormatter.h"

@interface PumpHistoryEventBase ()

@property (strong, nonatomic) ISO8601DateFormatter *dateFormatter;

@end

@implementation PumpHistoryEventBase

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (instancetype)initWithData:(NSData*)data andPumpModel:(PumpModel*)model
{
  self = [super init];
  if (self) {
    _dateFormatter = [[ISO8601DateFormatter alloc] init];
    _dateFormatter.includeTime = YES;
    _dateFormatter.useMillisecondPrecision = NO;
    _dateFormatter.timeZoneSeparator = ':';
    _dateFormatter.defaultTimeZone = [NSTimeZone timeZoneWithName:@"UTC"];

    _data = data;
    _pumpModel = model;
    if (_data.length > self.length) {
      _data = [_data subdataWithRange:NSMakeRange(0, [self length])];
    }
  }
  return self;
}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}


- (int) length {
  [NSException raise:@"Invalid Message" format:@"PumpHistoryEventBase does not implement length."];
  return 0;
}

+ (int) eventTypeCode {
  [NSException raise:@"Invalid Message" format:@"PumpHistoryEventBase does not implement eventTypeCode."];
  return 0;
}

- (uint8_t)byteAt:(NSInteger)index {
  if (_data && index < _data.length) {
    return ((uint8_t*)_data.bytes)[index];
  } else {
    return 0;
  }
}

- (NSDateComponents*) parseDateComponents:(NSInteger)offset {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  comps.second = [self byteAt:offset] & 0x3f;
  comps.minute = [self byteAt:offset+1] & 0x3f;
  comps.hour = [self byteAt:offset+2] & 0x1f;
  comps.day = [self byteAt:offset+3] & 0x1f;
  comps.month = ([self byteAt:offset] >>4 & 0xc) + ([self byteAt:offset+1] >> 6);
  comps.year = 2000 + ([self byteAt:offset+4] & 0b1111111);
  return comps;
}

- (NSDateComponents*) parseDate2Byte:(NSInteger)offset {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  comps.day = [self byteAt:offset] & 0x1f;
  comps.month = (([self byteAt:offset] & 0xe0) >> 4) + (([self byteAt:offset+1] & 0x80) >> 7);
  comps.year = 2000 + ([self byteAt:offset+1] & 0b1111111);
  return comps;
}

- (nullable NSDateComponents*) timestamp {
  return [self parseDateComponents:2];
}

- (NSString*) timestampStr {
  NSCalendar *cal = [NSCalendar currentCalendar];
  cal.timeZone = [NSTimeZone localTimeZone];
  cal.locale = [NSLocale currentLocale];
  NSDateComponents *c = [self timestamp];
  if (c == nil) {
    return @"<timestamp missing>";
  }
  NSDate *date = [cal dateFromComponents:c];
  
  return [self.dateFormatter stringFromDate:date timeZone:cal.timeZone];
}

- (NSString*) description {
  return [NSString stringWithFormat:@"%@ - %@", self.typeName, self.timestampStr];
}

- (NSString*) typeName {
  NSString *fullName = NSStringFromClass(self.class);
  if ([fullName hasPrefix:@"PHE"]) {
    return [fullName substringFromIndex:3];
  }
  return fullName;
}

- (NSDictionary*) asJSON {
  return @{
           @"_type": [self typeName],
           @"_raw": (self.data).hexadecimalString,
           @"timestamp": self.timestampStr,
           @"description": self.description
           };
}

@end
