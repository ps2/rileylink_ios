//
//  DeviceLink.h
//  RileyLink
//
//  Created by Pete Schwamb on 1/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageBase.h"

@interface DeviceLinkMessage : MessageBase

@property (nonatomic, readonly) NSInteger sequence;
@property (nonatomic, readonly) NSString *deviceAddress;

@end
