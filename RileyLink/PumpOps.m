//
//  PumpOps.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PumpOps.h"
#import "PumpOpsSynchronous.h"

@implementation PumpOps

- (nonnull instancetype)initWithPumpState:(nonnull PumpState *)a_pump andDevice:(nonnull RileyLinkBLEDevice *)a_device {
  self = [super init];
  if (self) {
    _pump = a_pump;
    _device = a_device;
  }
  return self;
}


- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (void) pressButton {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
    PumpOpsSynchronous *ops = [[PumpOpsSynchronous alloc] initWithPump:_pump andSession:session];
    [ops pressButton];
  }];
}

- (void) getPumpModel:(void (^ _Nullable)(NSString* _Nonnull))completionHandler {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
    PumpOpsSynchronous *ops = [[PumpOpsSynchronous alloc] initWithPump:_pump andSession:session];
    NSString *model = [ops getPumpModel];
    dispatch_async(dispatch_get_main_queue(),^{
      completionHandler(model);
    });
  }];
}

- (void) getBatteryVoltage:(void (^ _Nullable)(NSString * _Nonnull, float))completionHandler {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
    PumpOpsSynchronous *ops = [[PumpOpsSynchronous alloc] initWithPump:_pump andSession:session];
    NSDictionary *results = [ops getBatteryVoltage];
    dispatch_async(dispatch_get_main_queue(),^{
      completionHandler(results[@"status"], [results[@"value"] floatValue]);
    });
  }];
}

- (void) getHistoryPage:(NSInteger)page withHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
    PumpOpsSynchronous *ops = [[PumpOpsSynchronous alloc] initWithPump:_pump andSession:session];
    NSDictionary *res = [ops dumpHistoryPage:0];
    dispatch_async(dispatch_get_main_queue(),^{
      completionHandler(res);
    });
  }];  
}

- (void) tunePump:(void (^ _Nullable)(NSDictionary * _Nonnull))completionHandler {
  [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
    PumpOpsSynchronous *ops = [[PumpOpsSynchronous alloc] initWithPump:_pump andSession:session];
    NSDictionary *res = [ops scanForPump];
    dispatch_async(dispatch_get_main_queue(),^{
      completionHandler(res);
    });
  }];
}

@end
