//
//  PumpHistoryEventBase.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PumpHistoryEventBase : NSObject

@property (nonatomic, nonnull, readonly, strong) NSData *data;
@property (nonatomic, nullable, readonly, strong) NSString *pumpModel;

- (nonnull instancetype)initWithData:(nonnull NSData *)data andPumpModel:(nullable NSString *)model;

+ (int) eventTypeCode;

- (int) length;
- (uint8_t)byteAt:(NSInteger)index;
- (nonnull NSDateComponents*) parseDateComponents:(NSInteger)offset;
- (nonnull NSDateComponents*) parseDate2Byte:(NSInteger)offset;
- (nonnull NSDateComponents*) timestamp;
- (nonnull NSString*) timestampStr;

@end
