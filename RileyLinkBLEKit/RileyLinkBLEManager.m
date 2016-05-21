//
//  RileyLink.m
//  RileyLink
//
//  Created by Pete Schwamb on 8/5/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import "RileyLinkBLEManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "RileyLinkBLEDevice.h"

@interface RileyLinkBLEManager () <CBCentralManagerDelegate> {
    NSMutableDictionary *_devicesById; // RileyLinkBLEDevices by UUID
}

@property (strong, nonatomic) CBCentralManager *centralManager;

@end


@implementation RileyLinkBLEManager

+ (NSArray *)UUIDsFromUUIDStrings:(NSArray *)UUIDStrings
              excludingAttributes:(NSArray *)attributes {
    NSMutableArray *unmatchedUUIDStrings = [UUIDStrings mutableCopy];
    
    for (CBAttribute *attribute in attributes) {
        [unmatchedUUIDStrings removeObject:attribute.UUID.UUIDString];
    }
    
    NSMutableArray *UUIDs = [NSMutableArray array];
    
    for (NSString *UUIDString in unmatchedUUIDStrings) {
        [UUIDs addObject:[CBUUID UUIDWithString:UUIDString]];
    }
    
    return [NSArray arrayWithArray:UUIDs];
}

+ (RileyLinkBLEManager*)sharedManager {
    static RileyLinkBLEManager *sharedMyRileyLink = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyRileyLink = [[self alloc] init];
    });
    return sharedMyRileyLink;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil
                                                             options:@{CBCentralManagerOptionRestoreIdentifierKey: @"com.rileylink.CentralManager"}];
        
        _devicesById = [NSMutableDictionary dictionary];
        _autoConnectIds = [NSMutableSet set];
        
        [NSTimer scheduledTimerWithTimeInterval:5.0
                                         target:self
                                       selector:@selector(updateRSSI)
                                       userInfo:nil
                                        repeats:YES];
    }
    return self;
}

#pragma mark -

- (NSArray*)rileyLinkList {
    return _devicesById.allValues;
}

- (void) updateRSSI {
    if (_centralManager.isScanning) {
        for (RileyLinkBLEDevice *device in self.rileyLinkList) {
            [device.peripheral readRSSI];
        }
    }
}

- (RileyLinkBLEDevice *)addPeripheralToDeviceList:(CBPeripheral *)peripheral RSSI:(NSNumber *)RSSI {
    RileyLinkBLEDevice *d = _devicesById[peripheral.identifier.UUIDString];
    if (_devicesById[peripheral.identifier.UUIDString] == nil) {
        d = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];
        d.RSSI = RSSI;
        _devicesById[peripheral.identifier.UUIDString] = d;
        [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_ADDED object:d userInfo:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:self userInfo:@{@"device": d}];
    }
    
    if ([self.autoConnectIds containsObject:d.peripheralId]) {
        if (peripheral.state == CBPeripheralStateConnected) {
            [self centralManager:_centralManager
            didConnectPeripheral:peripheral];
        } else {
            [self connectPeripheral:d.peripheral];
        }
    }
    
    return d;
}

- (void)setScanningEnabled:(BOOL)scanningEnabled {
    if (scanningEnabled && _centralManager.state == CBCentralManagerStatePoweredOn) {
        [self startScan];
    } else if (!scanningEnabled || _centralManager.state == CBCentralManagerStatePoweredOff) {
        [_centralManager stopScan];
    }
    
    _scanningEnabled = scanningEnabled;
}

- (void)addPeripheralToAutoConnectList:(CBPeripheral *)peripheral {
    self.autoConnectIds = [self.autoConnectIds setByAddingObject:peripheral.identifier.UUIDString];
}

- (void)removePeripheralFromAutoConnectList:(CBPeripheral *)peripheral {
    NSMutableSet *mutableIDs = [self.autoConnectIds mutableCopy];
    [mutableIDs removeObject:peripheral.identifier.UUIDString];
    self.autoConnectIds = [NSSet setWithSet:mutableIDs];
}

- (BOOL)hasDiscoveredAllAutoConnectPeripherals
{
    return [self.autoConnectIds isSubsetOfSet:[NSSet setWithArray:_devicesById.allKeys]];
}

#pragma mark -

- (void)startScan {
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:RILEYLINK_SERVICE_UUID]] options:NULL];
    
    NSLog(@"Scanning started (state = %zd)", self.centralManager.state);
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    if (_centralManager.state == CBCentralManagerStatePoweredOn &&
        (peripheral.state == CBPeripheralStateDisconnected || peripheral.state == CBPeripheralStateDisconnecting)) {
        NSLog(@"Connecting to peripheral %zd:%@", _centralManager.state, peripheral);
        [_centralManager connectPeripheral:peripheral options:nil];
    } else {
        NSLog(@"Skipped request to connect to %@:%@", _centralManager, peripheral);
       [self centralManager:_centralManager didConnectPeripheral:peripheral];
    }
    
    [self addPeripheralToAutoConnectList:peripheral];
}

- (void)disconnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.state == CBPeripheralStateConnected || peripheral.state == CBPeripheralStateConnecting) {
        NSLog(@"Disconnecting from peripheral %@", peripheral);
        [self removePeripheralFromAutoConnectList:peripheral];
    } else {
        NSLog(@"Skipped request to disconnect from %@:%@", _centralManager, peripheral);
    }
    [_centralManager cancelPeripheralConnection:peripheral];
}

- (void)attemptReconnectForDisconnectedDevices {
    for (RileyLinkBLEDevice *device in self.rileyLinkList) {
        CBPeripheral *peripheral = device.peripheral;
        if (peripheral.state == CBPeripheralStateDisconnected
            && [self.autoConnectIds containsObject:device.peripheralId]) {
            NSLog(@"Attempting reconnect to %@", device);
            [self connectPeripheral:device.peripheral];
        }
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSLog(@"in willRestoreState: awoken from bg to handle ble updates");
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    
    for (CBPeripheral *peripheral in peripherals) {
        [self addPeripheralToDeviceList:peripheral RSSI:nil];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self attemptReconnectForDisconnectedDevices];
        
        if (![self hasDiscoveredAllAutoConnectPeripherals] || self.scanningEnabled) {
            [self startScan];
        }
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        [central stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    NSLog(@"localName =  %@", localName);
    
    
    [self addPeripheralToDeviceList:peripheral RSSI:RSSI];
    
    if (!self.isScanningEnabled && [self hasDiscoveredAllAutoConnectPeripherals]) {
        NSLog(@"All peripherals discovered. Scanning stopped (state = %zd)", self.centralManager.state);
        [central stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to peripheral: %@", error);
    
    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    [device connectionStateDidChange:error];
    
    [self attemptReconnectForDisconnectedDevices];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    NSLog(@"Discovering services");
    [peripheral discoverServices:[[self class] UUIDsFromUUIDStrings:@[RILEYLINK_SERVICE_UUID]
                                                excludingAttributes:peripheral.services]];
    
    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    
    [device connectionStateDidChange:nil];
    
    NSDictionary *attrs = @{@"peripheral": peripheral};
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_CONNECTED object:device userInfo:attrs];
    
    [peripheral readRSSI];
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    if (error) {
        NSLog(@"Disconnection: %@", error);
    }
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    
    attrs[@"peripheral"] = peripheral;
    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    
    [device connectionStateDidChange:error];
    
    if (error) {
        attrs[@"error"] = error;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:device userInfo:attrs];
    
    [self attemptReconnectForDisconnectedDevices];
}

@end
