//
//  PumpHistoryEventBase.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpHistoryEventBase.h"
#import "NSData+Conversion.h"

@implementation PumpHistoryEventBase

- (instancetype)initWithData:(NSData*)data andPumpModel:(PumpModel*)model
{
  self = [super init];
  if (self) {
    _data = data;
    _pumpModel = model;
    if (_data.length > self.length) {
      _data = [_data subdataWithRange:NSMakeRange(0, [self length])];
    }
  }
  return self;
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
  if (_data && index < [_data length]) {
    return ((uint8_t*)[_data bytes])[index];
  } else {
    return 0;
  }
}

- (NSDateComponents*) parseDateComponents:(NSInteger)offset {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  [comps setSecond:[self byteAt:offset] & 0x3f];
  [comps setMinute:[self byteAt:offset+1] & 0x3f];
  [comps setHour:[self byteAt:offset+2] & 0x1f];
  [comps setDay:[self byteAt:offset+3] & 0x1f];
  [comps setMonth:([self byteAt:offset] >>4 & 0xc) + ([self byteAt:offset+1] >> 6)];
  [comps setYear:2000 + ([self byteAt:offset+4] & 0b1111111)];
  return comps;
}

- (NSDateComponents*) parseDate2Byte:(NSInteger)offset {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  [comps setDay:[self byteAt:offset] & 0x1f];
  [comps setMonth:(([self byteAt:offset] & 0xe0) >> 4) + (([self byteAt:offset+1] & 0x80) >> 7)];
  [comps setYear:2000 + ([self byteAt:offset+1] & 0b1111111)];
  return comps;
}

- (nonnull NSDateComponents*) timestamp {
  return [self parseDateComponents:2];
}

- (NSString*) timestampStr {
  NSDateComponents *c = [self timestamp];
  if (c == nil) {
    return @"<timestamp missing>";
  }
  if (c.minute == NSDateComponentUndefined && c.hour == NSDateComponentUndefined && c.second == NSDateComponentUndefined) {
    return [NSString stringWithFormat:@"%d/%d/%d",
            (int)c.year, (int)c.month, (int)c.day];
  }
  return [NSString stringWithFormat:@"%d-%d-%dT%02d:%02d:%02d",
          (int)c.year, (int)c.month, (int)c.day, (int)c.hour, (int)c.minute, (int)c.second];
}

- (NSString*) description {
  return [NSString stringWithFormat:@"%@ - %@", self.class, self.timestampStr];
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
           @"_raw": [self.data hexadecimalString],
           @"timestamp": self.timestampStr,
           @"description": self.description
           };
}

@end
