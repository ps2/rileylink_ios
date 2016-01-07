//
//  PHEChangeOtherDeviceID.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PHEChangeOtherDeviceID.h"

@implementation PHEChangeOtherDeviceID

+ (int) eventTypeCode {
  return 0x7d;
}

- (int) length {
  return 37;
}


@end
