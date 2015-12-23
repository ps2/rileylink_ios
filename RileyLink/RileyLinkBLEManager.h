//
//  RileyLink.h
//  RileyLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RileyLinkBLEDevice.h"

#define RILEYLINK_EVENT_LIST_UPDATED        @"RILEYLINK_EVENT_LIST_UPDATED"
#define RILEYLINK_EVENT_PACKET_RECEIVED     @"RILEYLINK_EVENT_PACKET_RECEIVED"
#define RILEYLINK_EVENT_DEVICE_CONNECTED    @"RILEYLINK_EVENT_DEVICE_CONNECTED"
#define RILEYLINK_EVENT_DEVICE_DISCONNECTED @"RILEYLINK_EVENT_DEVICE_DISCONNECTED"

#define RILEYLINK_SERVICE_UUID       @"d39f1890-17eb-11e4-8c21-0800200c9a66"

#define RILEYLINK_RX_PACKET_UUID     @"2fb1a490-1940-11e4-8c21-0800200c9a66"
#define RILEYLINK_RX_CHANNEL_UUID    @"d93b2af0-1ea8-11e4-8c21-0800200c9a66"
#define RILEYLINK_PACKET_COUNT       @"41825a20-7402-11e4-8c21-0800200c9a66"
#define RILEYLINK_TX_PACKET_UUID     @"2fb1a490-1941-11e4-8c21-0800200c9a66"
#define RILEYLINK_TX_TRIGGER_UUID    @"2fb1a490-1942-11e4-8c21-0800200c9a66"
#define RILEYLINK_TX_CHANNEL_UUID    @"d93b2af0-1458-11e4-8c21-0800200c9a66"
#define RILEYLINK_CUSTOM_NAME_UUID   @"d93b2af0-1e28-11e4-8c21-0800200c9a66"


@interface RileyLinkBLEManager : NSObject

@property (nonatomic, nonnull, readonly, copy) NSArray *rileyLinkList;

- (void)connectPeripheral:(nonnull CBPeripheral *)peripheral;
- (void)disconnectPeripheral:(nonnull CBPeripheral *)peripheral;

+ (nonnull instancetype)sharedManager;

@property (nonatomic, nonnull, strong) NSSet *autoConnectIds;
@property (nonatomic, getter=isScanningEnabled) BOOL scanningEnabled;

/**
 Converts an array of UUID strings to CBUUID objects, excluding those represented in an array of CBAttribute objects.

 @param UUIDStrings An array of UUID string representations to filter
 @param attributes  An array of CBAttribute objects to exclude

 @return An array of CBUUID objects
 */
+ (nonnull NSArray *)UUIDsFromUUIDStrings:(nonnull NSArray *)UUIDStrings excludingAttributes:(nullable NSArray *)attributes;

@end

