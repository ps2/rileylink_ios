//
//  DeviceLink.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "DeviceLinkMessage.h"
#import "NSData+Conversion.h"

@implementation DeviceLinkMessage

- (NSDictionary*) bitBlocks {
  return @{@"sequence": @[@1, @7]
           };
}

- (NSInteger) sequence {
  return [self getBits:@"sequence"];
}

- (NSString*) deviceAddress {
  return [[self.data hexadecimalString] substringWithRange:NSMakeRange(2, 6)];
}

@end
