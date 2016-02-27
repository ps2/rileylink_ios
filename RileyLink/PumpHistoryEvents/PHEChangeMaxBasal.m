//
//  PHEChangeMaxBasal.m
//  RileyLink
//
//  Created by Pete Schwamb on 2/23/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "PHEChangeMaxBasal.h"

@implementation PHEChangeMaxBasal

+ (int) eventTypeCode {
  return 0x2c;
}


- (int) length {
  return 7;
}

@end
