//
//  RileyLinkBLE.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "RileyLinkBLEDevice.h"
#import "RileyLinkBLEManager.h"
#import "NSData+Conversion.h"
#import "SendAndListenCmd.h"
#import "GetPacketCmd.h"
#import "GetVersionCmd.h"
#import "RFPacket.h"


// See impl at bottom of file.
@interface RileyLinkCmdSession ()
@property (nonatomic, weak) RileyLinkBLEDevice *device;
@end


@interface RileyLinkBLEDevice () <CBPeripheralDelegate> {
    CBCharacteristic *dataCharacteristic;
    CBCharacteristic *responseCountCharacteristic;
    CBCharacteristic *customNameCharacteristic;
    CBCharacteristic *timerTickCharacteristic;
    CBCharacteristic *firmwareVersionCharacteristic;
    NSMutableArray *incomingPackets;
    NSMutableData *inBuf;
    NSData *endOfResponseMarker;
    BOOL idleListeningEnabled;
    uint8_t idleListenChannel;
    BOOL fetchingResponse;
    CmdBase *currentCommand;
    BOOL runningIdle;
    BOOL runningSession;
    BOOL ready;
    BOOL haveResponseCount;
    dispatch_group_t cmdDispatchGroup;
    dispatch_group_t idleDetectDispatchGroup;
}

@property (nonatomic, nonnull, strong) CBPeripheral * peripheral;
@property (nonatomic, nonnull, strong) dispatch_queue_t serialDispatchQueue;

@end


@implementation RileyLinkBLEDevice

@synthesize peripheral = _peripheral;
@synthesize lastIdle = _lastIdle;
@synthesize firmwareVersion = _firmwareVersion;
@synthesize bleFirmwareVersion = _bleFirmwareVersion;

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self) {
        // All processes that interact that run commands on this device should be serialized through
        // this queue.
        _serialDispatchQueue = dispatch_queue_create("com.rileylink.rlbledevice", DISPATCH_QUEUE_SERIAL);
        
        cmdDispatchGroup = dispatch_group_create();
        idleDetectDispatchGroup = dispatch_group_create();
        
        _idleTimeoutMS = 60 * 1000;
        _timerTickEnabled = YES;
        
        incomingPackets = [NSMutableArray array];
        
        inBuf = [NSMutableData data];
        endOfResponseMarker = [NSData dataWithHexadecimalString:@"00"];
        
        _peripheral = peripheral;
        _peripheral.delegate = self;
        
        for (CBService *service in _peripheral.services) {
            [self setCharacteristicsFromService:service];
        }
    }
    return self;
}

- (instancetype)init NS_UNAVAILABLE
{
    return nil;
}

- (NSString *)name
{
    return self.peripheral.name;
}

- (NSString *)peripheralId
{
    return self.peripheral.identifier.UUIDString;
}

- (void)setTimerTickEnabled:(BOOL)timerTickEnabled
{
    _timerTickEnabled = timerTickEnabled;
    
    if (timerTickCharacteristic != nil &&
        timerTickCharacteristic.isNotifying != timerTickEnabled &&
        self.peripheral.state == CBPeripheralStateConnected)
    {
        [self.peripheral setNotifyValue:_timerTickEnabled
                      forCharacteristic:timerTickCharacteristic];
    }
}

- (void) runSessionWithName:(nonnull NSString*)name usingBlock:(void (^ _Nonnull)(RileyLinkCmdSession* _Nonnull))proc {
    dispatch_group_enter(idleDetectDispatchGroup);
    RileyLinkCmdSession *session = [[RileyLinkCmdSession alloc] init];
    session.device = self;
    dispatch_async(_serialDispatchQueue, ^{
        runningSession = YES;
        NSLog(@"======================== %@ ===========================", name);
        proc(session);
        NSLog(@"------------------------ %@ ---------------------------", name);
        runningSession = NO;
        dispatch_group_leave(idleDetectDispatchGroup);
    });
    
    dispatch_group_notify(idleDetectDispatchGroup,
                          dispatch_get_main_queue(), ^{
                              NSLog(@"idleDetectDispatchGroup empty");
                              [self assertIdleListening];
                          });
}

- (BOOL) doCmd:(nonnull CmdBase*)cmd withTimeoutMs:(NSInteger)timeoutMS {
    dispatch_group_enter(cmdDispatchGroup);
    BOOL timedOut = NO;
    currentCommand = cmd;
    [self issueCommand:cmd];
    dispatch_time_t timeoutAt = dispatch_time(DISPATCH_TIME_NOW, timeoutMS * NSEC_PER_MSEC);
    if (dispatch_group_wait(cmdDispatchGroup,timeoutAt) != 0) {
        NSLog(@"No response from RileyLink... timing out command.");
        if (dataCharacteristic != nil) {
            [self.peripheral readValueForCharacteristic:dataCharacteristic];
        }
        dispatch_group_leave(cmdDispatchGroup);
        currentCommand = nil;
        timedOut = YES;
    }
    return !timedOut;
}

- (void) issueCommand:(nonnull CmdBase*)cmd {
    if (dataCharacteristic == nil) {
        NSLog(@"Ignoring command issued before we have discovered characteristics");
        return;
    }
    NSLog(@"Writing command to data characteristic: %@", [cmd.data hexadecimalString]);
    // 255 is the real limit (buf limit in bgscript), but we set the limit at 220, as we need room for escaping special chars.
    if (cmd.data.length > 220) {
        NSLog(@"********** Warning: packet too large: %zd bytes ************", cmd.data.length);
    } else {
        uint8_t count = cmd.data.length;
        NSMutableData *outBuf = [NSMutableData dataWithBytes:&count length:1];
        [outBuf appendData:cmd.data];
        [self.peripheral writeValue:outBuf forCharacteristic:dataCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Could not write characteristic: %@", error);
        return;
    }
    if (characteristic == customNameCharacteristic) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];
    }
    //NSLog(@"Did write characteristic: %@", characteristic.UUID);
}

- (RileyLinkState) state {
    RileyLinkState rval;
    switch (self.peripheral.state) {
        case CBPeripheralStateConnected:
            rval = RileyLinkStateConnected;
            break;
        case CBPeripheralStateConnecting:
            rval = RileyLinkStateConnecting;
            break;
        default:
            rval = RileyLinkStateDisconnected;
            break;
    }
    return rval;
}

- (void)connectionStateDidChange:(NSError *)error
{
    switch (self.peripheral.state) {
        case CBPeripheralStateConnected:
            [self assertIdleListening];
            break;
        case CBPeripheralStateDisconnected:
            runningIdle = NO;
            runningSession = NO;
            break;
        case CBPeripheralStateConnecting:
        case CBPeripheralStateDisconnecting:
            break;
    }
}

- (void)setCharacteristicsFromService:(CBService *)service {
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
            [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            responseCountCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_DATA_UUID]]) {
            dataCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_CUSTOM_NAME_UUID]]) {
            customNameCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_TIMER_TICK_UUID]]) {
            [self.peripheral setNotifyValue:_timerTickEnabled forCharacteristic:characteristic];
            timerTickCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_FIRMWARE_VERSION_UUID]]) {
            firmwareVersionCharacteristic = characteristic;
            [service.peripheral readValueForCharacteristic:firmwareVersionCharacteristic];
        }
    }
    
    NSDictionary *attrs = @{@"peripheral": self.peripheral};
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_ATTRS_DISCOVERED object:self userInfo:attrs];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Failure while discovering services: %@", error);
        return;
    }
    //NSLog(@"didDiscoverServices: %@, %@", peripheral, peripheral.services);
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_SERVICE_UUID]]) {
            [peripheral discoverCharacteristics:[RileyLinkBLEManager UUIDsFromUUIDStrings:@[RILEYLINK_RESPONSE_COUNT_UUID,
                                                                                            RILEYLINK_DATA_UUID,
                                                                                            RILEYLINK_CUSTOM_NAME_UUID,
                                                                                            RILEYLINK_TIMER_TICK_UUID,
                                                                                            RILEYLINK_FIRMWARE_VERSION_UUID]
                                                                      excludingAttributes:service.characteristics]
                                     forService:service];
        }
    }
    // Discover other characteristics
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error reading RSSI: %@", [error localizedDescription]);
    } else {
        dispatch_async(dispatch_get_main_queue(),^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_RSSI_CHANGED object:self userInfo:@{@"RSSI": RSSI}];
        });
        self.RSSI = RSSI;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    [self setCharacteristicsFromService:service];
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
     [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_NAME_CHANGED object:self userInfo:@{@"Name": peripheral.name}];
}

- (void)checkVersion {
    [self runSessionWithName:@"Check version" usingBlock:^(RileyLinkCmdSession * _Nonnull s) {
        GetVersionCmd *cmd = [[GetVersionCmd alloc] init];
        NSString *foundVersion;
        BOOL versionOK = NO;
        // We run two commands here, to flush out responses to any old commands
        [s doCmd:cmd withTimeoutMs:5000];
        if ([s doCmd:cmd withTimeoutMs:1000]) {
            foundVersion = [[NSString alloc] initWithData:cmd.response encoding:NSUTF8StringEncoding];
            NSLog(@"Got version: %@", foundVersion);
            
            switch ([self firmwareStateForVersionString:foundVersion]) {
                case SubgRfspyVersionStateUnknown:
                case SubgRfspyVersionStateInvalid:
                    NSLog(@"Unable to parse version... expecting 0.x, found %@", foundVersion);
                    break;
                case SubgRfspyVersionStateUpToDate:
                    versionOK = YES;
                    break;
                case SubgRfspyVersionStateOutOfDate:
                    NSLog(@"The firmware version on this RileyLink is out of date. Found version\"%@\". Please use subg_rfspy version 0.7 or newer.", foundVersion);
                    break;
            }
            
            _firmwareVersion = foundVersion;
        } else {
            NSLog(@"Unable to retrieve version from RileyLink. Get version command timed out.");
        }
        
        if (versionOK) {
            ready = YES;
            dispatch_async(dispatch_get_main_queue(),^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_READY object:self];
            });
        }
    }];
}

- (SubgRfspyVersionState)firmwareStateForVersionString:(NSString *)firmwareVersion
{
    if (firmwareVersion == nil) {
        return SubgRfspyVersionStateUnknown;
    }
    
    NSRange range = [firmwareVersion rangeOfString:@"subg_rfspy"];
    
    if (range.location == 0 && firmwareVersion.length > 11) {
        NSString *numberPart = [firmwareVersion substringFromIndex:11];
        NSArray *versionComponents = [numberPart componentsSeparatedByString:@"."];
        
        if (versionComponents.count > 1) {
            NSInteger major = [versionComponents[0] integerValue];
            NSInteger minor = [versionComponents[1] integerValue];
            
            if (major <= 0 && minor < 8) {
                return SubgRfspyVersionStateOutOfDate;
            } else {
                return SubgRfspyVersionStateUpToDate;
            }
        } else {
            return SubgRfspyVersionStateInvalid;
        }
    } else {
        return SubgRfspyVersionStateInvalid;
    }
}

- (SubgRfspyVersionState)firmwareState
{
    return [self firmwareStateForVersionString:_firmwareVersion];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error updating %@: %@", characteristic, error);
        return;
    }
    //NSLog(@"didUpdateValueForCharacteristic: %@", characteristic);
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_DATA_UUID]]) {
        [self dataReceivedFromRL:characteristic.value];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
        if (!haveResponseCount) {
            // The first time we get a notice on this is just from connecting.
            haveResponseCount = YES;
            [self checkVersion];
        } else {
            const unsigned char responseCount = ((const unsigned char*)(characteristic.value).bytes)[0];
            NSLog(@"Updated response count: %d", responseCount);
            [peripheral readValueForCharacteristic:dataCharacteristic];
        }
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_TIMER_TICK_UUID]]) {
        const unsigned char timerTick = ((const unsigned char*)(characteristic.value).bytes)[0];
        [self assertIdleListening];
        [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_TIMER_TICK object:self];
        NSLog(@"Updated timer tick: %d", timerTick);
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_FIRMWARE_VERSION_UUID]]) {
        _bleFirmwareVersion = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    }
}

- (void)dataReceivedFromRL:(NSData*) data {
    //NSLog(@"******* New Data: %@", [data hexadecimalString]);
    [inBuf appendData:data];
    
    while(inBuf.length > 0) {
        NSRange endOfResp = [inBuf rangeOfData:endOfResponseMarker options:0 range:NSMakeRange(0, inBuf.length)];
        
        NSData *fullResponse;
        if (endOfResp.location != NSNotFound) {
            fullResponse = [inBuf subdataWithRange:NSMakeRange(0, endOfResp.location)];
            //NSLog(@"******* Full response: %@", [fullResponse hexadecimalString]);
            NSInteger remainder = inBuf.length - endOfResp.location - 1;
            if (remainder > 0) {
                inBuf = [[inBuf subdataWithRange:NSMakeRange(endOfResp.location+1, remainder)] mutableCopy];
                //NSLog(@"******* Remainder: %@", [inBuf hexadecimalString]);
            } else {
                inBuf = [NSMutableData data];
            }
        } else {
            //NSLog(@"******* Buffering: %@", [inBuf hexadecimalString]);
        }
        
        if (fullResponse) {
            if (runningIdle) {
                NSLog(@"Response to idle: %@", [fullResponse hexadecimalString]);
                runningIdle = NO;
                [self handleIdleListenerResponse:fullResponse];
                if (!runningSession) {
                    if (inBuf.length > 0) {
                        NSLog(@"clearing unexpected buffer data: %@", [inBuf hexadecimalString]);
                        inBuf = [NSMutableData data];
                    }
                    [self onIdle];
                }
            } else if (currentCommand) {
                NSLog(@"Response to command: %@", [fullResponse hexadecimalString]);
                currentCommand.response = fullResponse;
                if (inBuf.length > 0) {
                    // This happens when connecting to a RL that is still running a command
                    // from a previous connection.
                    NSLog(@"Dropping extraneous data: %@", [inBuf hexadecimalString]);
                    inBuf.length = 0;
                }
                currentCommand = nil;
                dispatch_group_leave(cmdDispatchGroup);
            } else {
                NSLog(@"Received data but no outstanding command!");
                inBuf.length = 0;
            }
        } else {
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"Updated notification state for %@, %@", characteristic, error);
}

- (void)cleanup {
    NSLog(@"Entering cleanup");
    
    // See if we are subscribed to a characteristic on the peripheral
    for (CBService *service in self.peripheral.services) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:RILEYLINK_RESPONSE_COUNT_UUID]]) {
                if (characteristic.isNotifying) {
                    [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
                    return;
                }
            }
        }
    }
    
    dataCharacteristic = nil;
    responseCountCharacteristic = nil;
    customNameCharacteristic = nil;
    firmwareVersionCharacteristic = nil;
}

- (NSString*) deviceURI {
    return [@"rileylink://" stringByAppendingString:self.name];
}

- (void) setCustomName:(nonnull NSString*)customName {
    if (customNameCharacteristic) {
        NSData *data = [customName dataUsingEncoding:NSUTF8StringEncoding];
        [self.peripheral writeValue:data forCharacteristic:customNameCharacteristic type:CBCharacteristicWriteWithResponse];
    } else {
        NSLog(@"Missing customNameCharacteristic");
    }
}

- (void) onIdle {
    if (idleListeningEnabled && _peripheral.state == CBPeripheralStateConnected) {
        runningIdle = YES;
        NSLog(@"Starting idle RX");
        GetPacketCmd *cmd = [[GetPacketCmd alloc] init];
        cmd.listenChannel = idleListenChannel;
        cmd.timeoutMS = _idleTimeoutMS;
        [self issueCommand:cmd];
        
        _lastIdle = [NSDate date];
    }
}

- (void) enableIdleListeningOnChannel:(uint8_t)channel {
    idleListeningEnabled = YES;
    idleListenChannel = channel;
    
    [self assertIdleListening];
}

- (void) disableIdleListening {
    idleListeningEnabled = NO;
    runningIdle = NO;
}

- (void) assertIdleListening {
    if (idleListeningEnabled && !runningSession) {
        NSTimeInterval resetIdleAfterInterval = 2.0 * (float)_idleTimeoutMS / 1000.0;
        
        if (!runningIdle || ([NSDate dateWithTimeIntervalSinceNow:-resetIdleAfterInterval] > _lastIdle)) {
            [self onIdle];
        }
    }
}

- (void) handleIdleListenerResponse:(NSData *)response {
    if (response.length > 3) {
        // This is a response to our idle listen command
        RFPacket *packet = [[RFPacket alloc] initWithRFSPYResponse:response];
        if (packet.data) {
            packet.capturedAt = [NSDate date];
            NSLog(@"Read packet (%d): %zd bytes", packet.rssi, packet.data.length);
            NSDictionary *attrs = @{
                                    @"packet": packet,
                                    @"peripheral": self.peripheral,
                                    };
            [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_IDLE_RESPONSE_RECEIVED object:self userInfo:attrs];
        }
    } else if (response.length > 0) {
        uint8_t errorCode = ((uint8_t*)response.bytes)[0];
        switch (errorCode) {
            case SubgRfspyErrorRxTimeout:
                NSLog(@"Idle rx timeout");
                break;
            case SubgRfspyErrorCmdInterrupted:
                NSLog(@"Idle rx command interrupted.");
                break;
            case SubgRfspyErrorZeroData:
                NSLog(@"Idle rx zero data?!?!");
                break;
            default:
                NSLog(@"Unexpected response to idle rx command: %@", [response hexadecimalString]);
                break;
        }
    } else {
        NSLog(@"Idle command got empty response!!");
    }
}

@end

@implementation RileyLinkCmdSession
- (BOOL) doCmd:(nonnull CmdBase*)cmd withTimeoutMs:(NSInteger)timeoutMS {
    return [_device doCmd:cmd withTimeoutMs:timeoutMS];
}
@end


