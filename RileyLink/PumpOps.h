//
//  PumpOps.h
//  RileyLink
//
//  Created by Pete Schwamb on 1/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

@import UIKit;
#import "PumpState.h"
#import "RileyLinkBLEDevice.h"

@interface PumpOps : NSObject

- (nonnull instancetype)initWithPumpState:(nonnull PumpState *)pump andDevice:(nonnull RileyLinkBLEDevice *)device NS_DESIGNATED_INITIALIZER;

- (void) pressButton;
- (void) getPumpModel:(void (^ _Nullable)(NSString* _Nonnull))completionHandler;
- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler;
- (void) getHistoryPage:(NSInteger)page withHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler;
- (void) tunePump:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler;

@property (readonly, strong, nonatomic, nonnull) PumpState *pump;
@property (readonly, strong, nonatomic, nonnull) RileyLinkBLEDevice *device;

@end
