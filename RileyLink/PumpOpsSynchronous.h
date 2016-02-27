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
@property (NS_NONATOMIC_IOSONLY, getter=getPumpModel, readonly, copy) NSString * _Nullable pumpModel;
@property (NS_NONATOMIC_IOSONLY, getter=getBatteryVoltage, readonly, copy) NSDictionary * _Nonnull batteryVoltage;
- (NSDictionary* _Nonnull) getHistoryPage:(uint8_t)pageNum;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary * _Nonnull scanForPump;

@end
