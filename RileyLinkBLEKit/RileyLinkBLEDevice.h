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

extern NSString * _Nonnull const SubgRfspyErrorDomain;

typedef NS_ENUM(NSUInteger, SubgRfspyError) {
  SubgRfspyErrorRxTimeout = 0xaa,
  SubgRfspyErrorCmdInterrupted = 0xbb,
  SubgRfspyErrorZeroData = 0xcc
};

typedef NS_ENUM(NSUInteger, SubgRfspyVersionState) {
  SubgRfspyVersionStateUnknown = 0,
  SubgRfspyVersionStateUpToDate,
  SubgRfspyVersionStateOutOfDate,
  SubgRfspyVersionStateInvalid
};


#define ERROR_RX_TIMEOUT 0xaa
#define ERROR_CMD_INTERRUPTED 0xbb
#define ERROR_ZERO_DATA 0xcc

#define RILEYLINK_FREQ_XTAL 24000000

#define EXPECTED_MAX_BLE_LATENCY_MS 1500

@class RileyLinkCmdSession;

@interface RileyLinkBLEDevice : NSObject

@property (nonatomic, nullable, readonly) NSString * name;
@property (nonatomic, nullable, strong) NSNumber * RSSI;
@property (nonatomic, nonnull, readonly) NSString * peripheralId;
@property (nonatomic, nonnull, strong) CBPeripheral * peripheral;

@property (nonatomic, readonly) RileyLinkState state;

@property (nonatomic, readonly, copy, nonnull) NSString * deviceURI;

@property (nonatomic, readonly, nullable) NSString *firmwareVersion;

@property (nonatomic, readonly) SubgRfspyVersionState firmwareState;

@property (nonatomic, readonly, nullable) NSString *bleFirmwareVersion;

@property (nonatomic, readonly, nullable) NSDate *lastIdle;

@property (nonatomic) BOOL timerTickEnabled;

@property (nonatomic) uint32_t idleTimeoutMS;

/**
 Initializes the device with a specified peripheral

 @param peripheral The peripheral to represent

 @return A newly-initialized device
 */
- (nonnull instancetype)initWithPeripheral:(nonnull CBPeripheral *)peripheral NS_DESIGNATED_INITIALIZER;

- (void) connectionStateDidChange:(nullable NSError *)error;

- (void) runSessionWithName:(nonnull NSString*)name usingBlock:(void (^ _Nonnull)(RileyLinkCmdSession* _Nonnull))proc;
- (void) setCustomName:(nonnull NSString*)customName;
- (void) enableIdleListeningOnChannel:(uint8_t)channel;
- (void) disableIdleListening;
- (void) assertIdleListeningForcingRestart:(BOOL)forceRestart;

- (BOOL) doCmd:(nonnull CmdBase*)cmd withTimeoutMs:(NSInteger)timeoutMS;


@end
