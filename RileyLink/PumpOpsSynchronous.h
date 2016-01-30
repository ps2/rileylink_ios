//
//  PumpOpsSynchronous.h
//  RileyLink
//
//  Created by Pete Schwamb on 1/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PumpState.h"

@interface PumpOpsSynchronous : NSObject

- (nonnull instancetype)initWithPump:(nonnull PumpState *)pump andSession:(nonnull RileyLinkCmdSession *)session NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic, nonnull) PumpState *pump;
@property (readonly, strong, nonatomic, nonnull) RileyLinkCmdSession *session;

- (BOOL) wakeup:(uint8_t)duration;
- (void) pressButton;
- (NSString* _Nullable) getPumpModel;
- (NSDictionary* _Nonnull) getBatteryVoltage;
- (NSDictionary* _Nonnull) dumpHistoryPage:(uint8_t)pageNum;
- (NSDictionary* _Nonnull) scanForPump;

@end
