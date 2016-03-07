//
//  MinimedPacket.h
//  GlucoseLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageBase.h"
#import "RFPacket.h"

@class MessageBase;

@interface MinimedPacket : NSObject

- ( MessageBase* _Nullable)toMessage;

- (nonnull instancetype)initWithData:(nonnull NSData*)data NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithRFPacket:(nonnull RFPacket*)data NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) PacketType packetType;
@property (nonatomic, readonly) MessageType messageType;
@property (nonatomic, nonnull, readonly, copy) NSString *address;
@property (nonatomic, nullable, strong) NSData *data;
@property (nonatomic, assign) int rssi;

@end
