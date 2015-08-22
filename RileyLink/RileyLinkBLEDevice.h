//
//  RileyLinkBLE.h
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


typedef NS_ENUM(NSUInteger, RileyLinkState) {
  RILEY_LINK_STATE_CONNECTING,
  RILEY_LINK_STATE_CONNECTED,
  RILEY_LINK_STATE_DISCONNECTED
};

@interface RileyLinkBLEDevice : NSObject

@property (nonatomic, nullable, readonly) NSString * name;
@property (nonatomic, nullable, retain) NSNumber * RSSI;
@property (nonatomic, nonnull, readonly) NSString * peripheralId;
@property (nonatomic, nonnull, retain) CBPeripheral * peripheral;

@property (nonatomic, nonnull, readonly, copy) NSArray *packets;

@property (nonatomic, readonly) RileyLinkState state;

/**
 Initializes the device with a specified peripheral

 @param peripheral The peripheral to represent

 @return A newly-initialized device
 */
- (nonnull instancetype)initWithPeripheral:(nonnull CBPeripheral *)peripheral NS_DESIGNATED_INITIALIZER;

- (void) connect;
- (void) disconnect;
- (void) cancelSending;
- (void) setRXChannel:(unsigned char)channel;
- (void) setTXChannel:(unsigned char)channel;
- (void) sendPacketData:(nonnull NSData*)data;
- (void) sendPacketData:(nonnull NSData*)data withCount:(NSInteger)count andTimeBetweenPackets:(NSTimeInterval)timeBetweenPackets;

@end
