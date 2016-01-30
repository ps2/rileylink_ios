//
//  CRC8.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/26/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CRC8 : NSObject

+ (uint8_t) compute:(NSData*)data;

@end
