//
//  MeterMessage.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 5/30/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "MeterMessage.h"

@implementation MeterMessage

- (NSDictionary*) bitBlocks {
  return @{@"flags": @[@37, @2],
           @"glucose": @[@39, @9]
           };
}

- (BOOL) isAck {
  return [self getBits:@"flags"] == 3;
}

- (NSInteger) glucose {
  return [self getBits:@"glucose"];
}

- (NSInteger) bitsOffset {
  return 0;
}

@end
