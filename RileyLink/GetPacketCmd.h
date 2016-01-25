//
//  GetPacketCmd.h
//  RileyLink
//
//  Created by Pete Schwamb on 1/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CmdBase.h"


@interface GetPacketCmd : CmdBase

@property (nonatomic, assign) uint8_t listenChannel;
@property (nonatomic, assign) uint16_t timeoutMS;

@end
