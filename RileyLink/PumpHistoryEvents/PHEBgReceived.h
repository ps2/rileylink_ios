//
//  PHEBgReceived.h
//

#import <Foundation/Foundation.h>
#import "PumpHistoryEventBase.h"

@interface PHEBgReceived : PumpHistoryEventBase

- (int) bloodGlucose;

- (nonnull NSString*) meterId;

- (nonnull NSDateComponents*) timestamp;

@end
