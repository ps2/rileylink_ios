//
//  RileyLinkBLE.h
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;
#import "CmdBase.h"

typedef NS_ENUM(NSUInteger, RileyLinkState) {
  RileyLinkStateConnecting,
  RileyLinkStateConnected,
  RileyLinkStateDisconnected
};

@interface RileyLinkCmdRunner : NSObject
- (nonnull NSData*) doCmd:(nonnull CmdBase*)cmd;
@end

@interface RileyLinkBLEDevice : NSObject

@property (nonatomic, nullable, readonly) NSString * name;
@property (nonatomic, nullable, retain) NSNumber * RSSI;
@property (nonatomic, nonnull, readonly) NSString * peripheralId;
@property (nonatomic, nonnull, readonly, retain) CBPeripheral * peripheral;

@property (nonatomic, nonnull, readonly, copy) NSArray *packets;

@property (nonatomic, readonly) RileyLinkState state;

@property (nonatomic, readonly, copy, nonnull) NSString * deviceURI;

/**
 Initializes the device with a specified peripheral

 @param peripheral The peripheral to represent

 @return A newly-initialized device
 */
- (nonnull instancetype)initWithPeripheral:(nonnull CBPeripheral *)peripheral NS_DESIGNATED_INITIALIZER;

- (void) didDisconnect:(nullable NSError*)error;

- (void) dispatch:(void (^ _Nonnull)(RileyLinkCmdRunner* _Nonnull))proc;
- (void) setCustomName:(nonnull NSString*)customName;
- (void) enableIdleListeningOnChannel:(uint8_t)channel;
- (void) disableIdleListening;

@end
