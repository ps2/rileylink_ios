//
//  PHEDeleteOtherDeviceID.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PHEDeleteOtherDeviceID.h"

@implementation PHEDeleteOtherDeviceID

+ (int) eventTypeCode {
  return 0x82;
}

- (int) length {
  return 12;
}


@end
