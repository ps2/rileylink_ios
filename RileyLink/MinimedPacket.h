//
//  MinimedPacket.h
//  GlucoseLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MessageBase;

@interface MinimedPacket : NSObject

typedef NS_ENUM(unsigned char, PacketType) {
  PacketTypeSentry    = 0xa2,
  PacketTypeMeter     = 0xa5,
  PacketTypeCarelink  = 0xa7,
  PacketTypeSensor    = 0xa8
};

typedef NS_ENUM(unsigned char, MessageType) {
  MESSAGE_TYPE_ALERT = 0x01,
  MESSAGE_TYPE_ALERT_CLEARED = 0x02,
  MESSAGE_TYPE_DEVICE_TEST = 0x03,
  MESSAGE_TYPE_PUMP_STATUS = 0x04,
  MESSAGE_TYPE_ACK = 0x06,
  MESSAGE_TYPE_PUMP_BACKFILL = 0x08,
  MESSAGE_TYPE_FIND_DEVICE = 0x09,
  MESSAGE_TYPE_DEVICE_LINK = 0x0a,
  MESSAGE_TYPE_PUMP_DUMP = 0x0a,
  MESSAGE_TYPE_POWER = 0x5d,
  MESSAGE_TYPE_BUTTON_PRESS = 0x5b,
  MESSAGE_TYPE_GET_PUMP_MODEL = 0x8d,
  MESSAGE_TYPE_GET_BATTERY = 0x72,
  MESSAGE_TYPE_READ_HISTORY = 0x80,
};

- ( MessageBase* _Nullable)toMessage;

- (nonnull instancetype)initWithData:(nonnull NSData*)data NS_DESIGNATED_INITIALIZER;
@property (nonatomic, getter=isValid, readonly) BOOL valid;
@property (nonatomic, nullable, readonly, copy) NSString *hexadecimalString;
@property (nonatomic, readonly) PacketType packetType;
@property (nonatomic, readonly) MessageType messageType;
@property (nonatomic, nonnull, readonly, copy) NSString *address;
+ (nonnull NSData*)encodeData:(nonnull NSData*)data;

@property (nonatomic, nullable, strong) NSData *data;
@property (nonatomic, nullable, strong) NSDate *capturedAt;
@property (nonatomic, assign) int rssi;
@property (nonatomic, assign) int packetNumber;

@end
