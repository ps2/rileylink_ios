//
//  CRC16.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/26/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CRC16 : NSObject

+ (uint16_t) compute:(NSData*)data;

@end
