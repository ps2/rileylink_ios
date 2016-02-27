//
//  PumpHistoryEventBase.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PumpModel.h"

@interface PumpHistoryEventBase : NSObject

@property (nonatomic, nonnull, readonly, strong) NSData *data;
@property (nonatomic, nullable, readonly, strong) PumpModel *pumpModel;

- (nonnull instancetype)initWithData:(nonnull NSData *)data andPumpModel:(nullable PumpModel *)model NS_DESIGNATED_INITIALIZER;

+ (int) eventTypeCode;

@property (NS_NONATOMIC_IOSONLY, readonly) int length;
- (uint8_t)byteAt:(NSInteger)index;
- (nonnull NSDateComponents*) parseDateComponents:(NSInteger)offset;
- (nonnull NSDateComponents*) parseDate2Byte:(NSInteger)offset;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDateComponents * _Nullable timestamp;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull timestampStr;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary * _Nonnull asJSON;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull typeName;

@end
