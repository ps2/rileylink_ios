//
//  PumpState.h
//  RileyLink
//
//  Created by Pete Schwamb on 10/6/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RileyLinkBLEDevice.h"

@interface PumpState : NSObject

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)pumpId NS_DESIGNATED_INITIALIZER;

- (BOOL) isAwake;

@property (strong, nonatomic, nonnull) NSString *pumpId;
@property (strong, nonatomic, nonnull) NSDate *lastHistoryDump;
@property (strong, nonatomic, nonnull) NSDate *awakeUntil;

@end
