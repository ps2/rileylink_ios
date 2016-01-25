//
//  PHEChangeWatchdogMarriageProfile.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PHEChangeWatchdogMarriageProfile.h"

@implementation PHEChangeWatchdogMarriageProfile

+ (int) eventTypeCode {
  return 0x81;
}

- (int) length {
  return 12;
}

@end
