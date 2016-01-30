//
//  RileyLink.h
//  RileyLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RileyLinkBLEDevice.h"

#define RILEYLINK_EVENT_LIST_UPDATED            @"RILEYLINK_EVENT_LIST_UPDATED"
#define RILEYLINK_EVENT_PACKET_RECEIVED         @"RILEYLINK_EVENT_PACKET_RECEIVED"
#define RILEYLINK_EVENT_DEVICE_CONNECTED        @"RILEYLINK_EVENT_DEVICE_CONNECTED"
#define RILEYLINK_EVENT_DEVICE_DISCONNECTED     @"RILEYLINK_EVENT_DEVICE_DISCONNECTED"
#define RILEYLINK_EVENT_DEVICE_ATTRS_DISCOVERED @"RILEYLINK_EVENT_DEVICE_ATTRS_DISCOVERED"
#define RILEYLINK_EVENT_DEVICE_READY            @"RILEYLINK_EVENT_DEVICE_READY"

#define RILEYLINK_SERVICE_UUID         @"0235733b-99c5-4197-b856-69219c2a3845"
#define RILEYLINK_DATA_UUID            @"c842e849-5028-42e2-867c-016adada9155"
#define RILEYLINK_RESPONSE_COUNT_UUID  @"6e6c7910-b89e-43a5-a0fe-50c5e2b81f4a"
#define RILEYLINK_CUSTOM_NAME_UUID     @"d93b2af0-1e28-11e4-8c21-0800200c9a66"


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

