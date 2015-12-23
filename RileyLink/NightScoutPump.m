//
//  NightScoutPump.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/27/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//
//  Based on https://github.com/openaps/oref0/blob/master/lib/pump.js
//


#import "NightScoutPump.h"

@implementation NightScoutPump

- (NSArray*) translate:(NSArray*)treatments {
  NSMutableArray *results = [NSMutableArray array];
  for (NSDictionary *entry in treatments) {
    NSMutableDictionary *current = [entry mutableCopy];
    if ([current[@"_type"] isEqualToString:@"CalBGForPH"]) {
      current[@"eventType"] = @"<none>";
      current[@"glucose"] = current[@"amount"];
      current[@"glucoseType"] = @"Finger";
      current[@"notes"] = @"Pump received finger stick.";
    }
    [results addObject:current];
  }
  return results;
}

+ (NSArray*) process:(NSArray*)treatments {
  return [[[NightScoutPump alloc] init] translate: treatments];
}


@end
