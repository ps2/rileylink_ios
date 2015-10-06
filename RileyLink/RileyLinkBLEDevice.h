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
  RileyLinkStateConnecting,
  RileyLinkStateConnected,
  RileyLinkStateDisconnected
};

@interface RileyLinkBLEDevice : NSObject

@property (nonatomic, nullable, readonly) NSString * name;
@property (nonatomic, nullable, retain) NSNumber * RSSI;
@property (nonatomic, nonnull, readonly) NSString * peripheralId;
@property (nonatomic, nonnull, readonly, retain) CBPeripheral * peripheral;

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
- (void) didDisconnect:(nullable NSError*)error;
- (void) cancelSending;
- (void) setRXChannel:(unsigned char)channel;
- (void) setTXChannel:(unsigned char)channel;
- (void) sendPacketData:(nonnull NSData*)data;
- (void) sendPacketData:(nonnull NSData*)data withCount:(NSInteger)count andTimeBetweenPackets:(NSTimeInterval)timeBetweenPackets;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * __nonnull deviceURI;
- (void) setCustomName:(nonnull NSString*)customName;

@end
