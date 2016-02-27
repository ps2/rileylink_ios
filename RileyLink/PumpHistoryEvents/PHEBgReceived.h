//
//  PHEBgReceived.h
//

#import <Foundation/Foundation.h>
#import "PumpHistoryEventBase.h"

@interface PHEBgReceived : PumpHistoryEventBase

@property (NS_NONATOMIC_IOSONLY, readonly) int bloodGlucose;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull meterId;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDateComponents * _Nonnull timestamp;

@end
