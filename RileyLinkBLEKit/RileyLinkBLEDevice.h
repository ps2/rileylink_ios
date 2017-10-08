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

#define CC111X_REG_SYNC1    0x00
#define CC111X_REG_SYNC0    0x01
#define CC111X_REG_PKTLEN   0x02
#define CC111X_REG_PKTCTRL1 0x03
#define CC111X_REG_PKTCTRL0 0x04
#define CC111X_REG_FSCTRL1  0x07
#define CC111X_REG_FREQ2    0x09
#define CC111X_REG_FREQ1    0x0A
#define CC111X_REG_FREQ0    0x0B
#define CC111X_REG_MDMCFG4  0x0C
#define CC111X_REG_MDMCFG3  0x0D
#define CC111X_REG_MDMCFG2  0x0E
#define CC111X_REG_MDMCFG1  0x0F
#define CC111X_REG_MDMCFG0  0x10
#define CC111X_REG_DEVIATN  0x11
#define CC111X_REG_MCSM0    0x14
#define CC111X_REG_FOCCFG   0x15
#define CC111X_REG_AGCCTRL2 0x17
#define CC111X_REG_AGCCTRL1 0x18
#define CC111X_REG_AGCCTRL0 0x19
#define CC111X_REG_FREND1   0x1A
#define CC111X_REG_FREND0   0x1B
#define CC111X_REG_FSCAL3   0x1C
#define CC111X_REG_FSCAL2   0x1D
#define CC111X_REG_FSCAL1   0x1E
#define CC111X_REG_FSCAL0   0x1F
#define CC111X_REG_TEST1    0x24
#define CC111X_REG_TEST0    0x25
#define CC111X_REG_PA_TABLE0 0x2E


@interface RileyLinkCmdSession : NSObject
/**
 Runs a command synchronously. I.E. this method will not return until the command 
 finishes, or times out. Returns NO if the command timed out. The command's response
 is set if the command did not time out. 
 */
- (BOOL) doCmd:(nonnull CmdBase*)cmd withTimeoutMs:(NSInteger)timeoutMS;
@end

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

@end
