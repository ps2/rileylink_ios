//
//  PumpModels.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/19/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "PumpModel.h"

@interface PumpModel () {
  NSDictionary *settings;
}

@end


@implementation PumpModel


+ (PumpModel*) find:(NSString*)number {
  NSDictionary *base =  @{
                          @"larger": @NO,
                          @"hasLowSuspend": @NO,
                          @"strokePerUnit": @10
                          };
  
  NSDictionary *m523 =  @{
                          @"larger": @YES,
                          @"hasLowSuspend": @NO,
                          @"strokePerUnit": @40
                          };
  
  NSDictionary *m551 =  @{
                          @"larger": @YES,
                          @"hasLowSuspend": @YES,
                          @"strokePerUnit": @40
                          };
  
  
  
  return @{
    @"508": base,
    @"511": base,
    @"512": base,
    @"515": base,
    @"522": base,
    @"722": base,
    @"523": m523,
    @"723": m523,
    @"530": m523,
    @"730": m523,
    @"540": m523,
    @"740": m523,
    @"551": m551,
    @"554": m551,
    @"751": m551,
    @"754": m551
    }[number];
}

- (instancetype)initWithSettings:(NSDictionary*)newSettings
{
  self = [super init];
  if (self) {
    settings = newSettings;
  }
  return self;
}


- (BOOL) larger {
  return [settings[@"larger"] boolValue];
}

- (BOOL) hasLowSuspend {
  return [settings[@"hasLowSuspend"] boolValue];
}

- (NSInteger) strokesPerUnit {
  return [settings[@"strokesPerUnit"] integerValue];
}

@end
