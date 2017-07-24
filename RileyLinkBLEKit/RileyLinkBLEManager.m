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
    NSMutableSet<NSString *> *_autoConnectIDs;
    BOOL _scanningEnabled;
}

@property (nonnull, strong, nonatomic) CBCentralManager *centralManager;

@end


@implementation RileyLinkBLEManager

+ (NSArray<CBUUID *> *)UUIDsFromUUIDStrings:(NSArray<NSString *> *)UUIDStrings
              excludingAttributes:(NSArray<CBAttribute *> *)attributes {
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

- (instancetype)initWithAutoConnectIDs:(NSSet<NSString *> *)autoConnectIDs
{
    self = [super init];
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil
                                                             options:@{CBCentralManagerOptionRestoreIdentifierKey: @"com.rileylink.CentralManager"}];
        
        _devicesById = [NSMutableDictionary dictionary];
        _autoConnectIDs = [autoConnectIDs mutableCopy];
        _scanningEnabled = NO;
    }
    return self;
}

#pragma mark -

- (NSArray<RileyLinkBLEDevice *> *)rileyLinkList {
    return _devicesById.allValues;
}

- (RileyLinkBLEDevice *)addPeripheralToDeviceList:(CBPeripheral *)peripheral RSSI:(NSNumber *)RSSI {
    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    if (device == nil) {
        device = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];
        _devicesById[peripheral.identifier.UUIDString] = device;
        NSLog(@"RILEYLINK_EVENT_DEVICE_CREATED");
        [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_CREATED object:self userInfo:@{@"device": device}];
    } else {
        device.peripheral = peripheral;
    }

    if (RSSI != nil) {
        device.RSSI = RSSI;
    }

    if ([_autoConnectIDs containsObject:device.peripheralId]) {
        [self connectPeripheral:device.peripheral];
    }
    
    return device;
}

- (void)setScanningEnabled:(BOOL)scanningEnabled {
    _scanningEnabled = scanningEnabled;

    if (_centralManager.state == CBManagerStatePoweredOn) {
        if (_scanningEnabled) {
            [self startScan];
        } else if (_centralManager.isScanning) {
            [_centralManager stopScan];
        }
    }
}

- (void)addPeripheralToAutoConnectList:(CBPeripheral *)peripheral {
    [_autoConnectIDs addObject:peripheral.identifier.UUIDString];
}

- (void)removePeripheralFromAutoConnectList:(CBPeripheral *)peripheral {
    [_autoConnectIDs removeObject:peripheral.identifier.UUIDString];
}

- (BOOL)hasDiscoveredAllAutoConnectPeripherals
{
    return [_autoConnectIDs isSubsetOfSet:[NSSet setWithArray:_devicesById.allKeys]];
}

#pragma mark -

- (void)startScan {
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:RILEYLINK_SERVICE_UUID]] options:NULL];
    
    NSLog(@"Scanning started (state = %zd)", self.centralManager.state);
}

- (void)connectDevice:(RileyLinkBLEDevice *)device
{
    CBPeripheral *peripheral = [_centralManager retrievePeripheralsWithIdentifiers:@[device.peripheral.identifier]].firstObject;

    if (peripheral != nil) {
        device.peripheral = peripheral;

        [self connectPeripheral:peripheral];
    }
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    if (_centralManager.state == CBManagerStatePoweredOn) {
        if (peripheral.state != CBPeripheralStateConnected) {
            NSLog(@"Connecting to peripheral %zd:%@", _centralManager.state, peripheral);
            [_centralManager connectPeripheral:peripheral options:nil];
        } else {
            NSLog(@"Skipped request to connect to %@:%@", _centralManager, peripheral);
            [self centralManager:_centralManager didConnectPeripheral:peripheral];
        }
    }
    
    [self addPeripheralToAutoConnectList:peripheral];
}

- (void)disconnectDevice:(RileyLinkBLEDevice *)device
{
    CBPeripheral *peripheral = [_centralManager retrievePeripheralsWithIdentifiers:@[device.peripheral.identifier]].firstObject;

    if (peripheral != nil) {
        device.peripheral = peripheral;

        [self disconnectPeripheral:peripheral];
    }
}

- (void)disconnectPeripheral:(CBPeripheral *)peripheral
{
    if (_centralManager.state == CBManagerStatePoweredOn) {
        if (peripheral.state != CBPeripheralStateDisconnected) {
            NSLog(@"Disconnecting from peripheral %@", peripheral);
            [_centralManager cancelPeripheralConnection:peripheral];
        } else {
            NSLog(@"Skipped request to disconnect from %@:%@", _centralManager, peripheral);
            [self centralManager:_centralManager didDisconnectPeripheral:peripheral error:nil];
        }
    }

    [self removePeripheralFromAutoConnectList:peripheral];
}

- (void)attemptReconnectForDisconnectedDevices {
    for (RileyLinkBLEDevice *device in _devicesById.allValues) {
        if ([_autoConnectIDs containsObject:device.peripheralId]) {
            NSLog(@"Attempting reconnect to %@", device);
            [self connectDevice:device];
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
    if (central.state == CBManagerStatePoweredOn) {
        [self attemptReconnectForDisconnectedDevices];
        
        if (![self hasDiscoveredAllAutoConnectPeripherals] || _scanningEnabled) {
            [self startScan];
        } else if (central.isScanning) {
            [central stopScan];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {

    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    NSLog(@"localName =  %@", localName);
    
    
    [self addPeripheralToDeviceList:peripheral RSSI:RSSI];
    
    if (!_scanningEnabled && [self hasDiscoveredAllAutoConnectPeripherals] && central.isScanning) {
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
    NSLog(@"%s", __PRETTY_FUNCTION__);

    NSArray *servicesToDiscover = [[self class] UUIDsFromUUIDStrings:@[RILEYLINK_SERVICE_UUID]
                                                 excludingAttributes:peripheral.services];
    if (servicesToDiscover.count) {
        NSLog(@"Discovering services");
        [peripheral discoverServices:servicesToDiscover];
    }

    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    
    [device connectionStateDidChange:nil];

    if (device == nil) {
        return;
    }
    
    NSDictionary *attrs = @{@"peripheral": device.peripheral};
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_CONNECTED object:device userInfo:attrs];
    
    [device.peripheral readRSSI];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {

    if (error) {
        NSLog(@"Disconnection: %@", error);
    }
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    
    RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
    
    [device connectionStateDidChange:error];

    if (device == nil) {
        return;
    }

    attrs[@"peripheral"] = device.peripheral;

    if (error) {
        attrs[@"error"] = error;
    }

    NSLog(@"RILEYLINK_EVENT_DEVICE_DISCONNECTED");
    [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:device userInfo:attrs];
    
    [self attemptReconnectForDisconnectedDevices];
}

@end
