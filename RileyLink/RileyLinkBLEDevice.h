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

typedef NS_ENUM(NSUInteger, SubgRfspyError) {
  SubgRfspyErrorRxTimeout = 0xaa,
  SubgRfspyErrorCmdInterrupted = 0xbb,
  SubgRfspyErrorZeroData = 0xcc
};


#define ERROR_RX_TIMEOUT 0xaa
#define ERROR_CMD_INTERRUPTED 0xbb
#define ERROR_ZERO_DATA 0xcc


@interface RileyLinkCmdSession : NSObject
- (nonnull NSData *) doCmd:(nonnull CmdBase*)cmd withTimeoutMs:(NSInteger)timeoutMS;
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

- (void) runSession:(void (^ _Nonnull)(RileyLinkCmdSession* _Nonnull))proc;
- (void) setCustomName:(nonnull NSString*)customName;
- (void) enableIdleListeningOnChannel:(uint8_t)channel;
- (void) disableIdleListening;

@end
