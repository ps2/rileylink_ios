//
//  MessageBase.h
//  GlucoseLink
//
//  Created by Pete Schwamb on 5/26/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MinimedPacket.h"

@interface MessageBase : NSObject

@property (nonatomic, nonnull, readonly, strong) NSData *data;

- (nonnull instancetype)initWithData:(nonnull NSData*)data NS_DESIGNATED_INITIALIZER;
@property (nonatomic, nonnull, readonly, copy) NSDictionary *bitBlocks;
- (NSInteger) getBits:(nullable NSString*)key;
- (void) setBits:(nonnull NSString*)key toValue:(NSInteger)val;
- (unsigned char) getBitAtIndex:(NSInteger)idx;
- (NSInteger)bitsOffset;

@property (nonatomic, readonly) PacketType packetType;
@property (nonatomic, readonly) MessageType messageType;
@property (nonatomic, nonnull, readonly, copy) NSString *address;

@end
