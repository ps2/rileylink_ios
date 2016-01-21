//
//  HistoryFetcher.h
//  RileyLink
//
//  Created by Pete Schwamb on 1/20/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RileyLinkBLEDevice.h"

@interface HistoryFetcher : NSObject

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)pumpId andDevice:(nonnull RileyLinkBLEDevice *)device NS_DESIGNATED_INITIALIZER;

- (void) fetchPage:(uint8_t)pageNum completionHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler;

@property (readonly, strong, nonatomic, nonnull) RileyLinkBLEDevice *device;
@property (readonly, strong, nonatomic, nonnull) NSString *pumpId;

@end
