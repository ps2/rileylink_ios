//
//  PumpCommManager.h
//  RileyLink
//
//  Created by Pete Schwamb on 10/6/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RileyLinkBLEDevice.h"

@interface PumpCommManager : NSObject

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)pumpId andDevice:(nonnull RileyLinkBLEDevice *)device NS_DESIGNATED_INITIALIZER;

- (void)wakeup:(uint8_t)duration;
- (void)pressButton;

- (void) getPumpModel:(void (^ _Nullable)(NSString* _Nonnull))completionHandler;
- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler;
- (void) dumpHistoryPage:(uint8_t)pageNum completionHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler;

@property (readonly, strong, nonatomic, nonnull) RileyLinkBLEDevice *device;
@property (readonly, strong, nonatomic, nonnull) NSString *pumpId;


@end
