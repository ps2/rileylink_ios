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

+ (instancetype)sharedManager {
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
  }
  return self;
}

#pragma mark -

- (NSArray*)rileyLinkList {
    return _devicesById.allValues;
}

- (RileyLinkBLEDevice *)addPeripheralToDeviceList:(CBPeripheral *)peripheral {
    RileyLinkBLEDevice *d = _devicesById[peripheral.identifier.UUIDString];
    if (_devicesById[peripheral.identifier.UUIDString] == nil) {
        d = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];
        _devicesById[peripheral.identifier.UUIDString] = d;
    }

    if ([self.autoConnectIds containsObject:d.peripheralId]) {
        [self connectToRileyLink:d];
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

- (void)addDeviceToAutoConnectList:(RileyLinkBLEDevice*)device {
    self.autoConnectIds = [self.autoConnectIds setByAddingObject:device.peripheralId];
}

- (void)removeDeviceFromAutoConnectList:(RileyLinkBLEDevice*)device {
    NSMutableSet *mutableIDs = [self.autoConnectIds mutableCopy];
    [mutableIDs removeObject:device.peripheralId];
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

- (void)connectToRileyLink:(RileyLinkBLEDevice *)device {
    NSLog(@"Connecting to peripheral %@", device.peripheral);
    [_centralManager connectPeripheral:device.peripheral options:nil];
}

- (void)disconnectRileyLink:(RileyLinkBLEDevice *)device {
    NSLog(@"Disconnecting from peripheral %@", device.peripheral);
    [_centralManager cancelPeripheralConnection:device.peripheral];
}

- (void)attemptReconnectForDisconnectedDevices {
    for (RileyLinkBLEDevice *device in [self rileyLinkList]) {
        CBPeripheral *peripheral = device.peripheral;
        if (peripheral.state == CBPeripheralStateDisconnected
            && [self.autoConnectIds containsObject:device.peripheralId]) {
            NSLog(@"Attempting reconnect to %@", device);
            [self connectToRileyLink:device];
        }
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];

    for (CBPeripheral *peripheral in peripherals) {
        [self addPeripheralToDeviceList:peripheral];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBCentralManagerStatePoweredOn) {
        if ([self hasDiscoveredAllAutoConnectPeripherals]) {
            [self attemptReconnectForDisconnectedDevices];
        } else {
            [self startScan];
        }
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        [central stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
  
  NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);

  RileyLinkBLEDevice *device = [self addPeripheralToDeviceList:peripheral];

  device.RSSI = RSSI;

  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_LIST_UPDATED object:nil];

  if (!self.isScanningEnabled && [self hasDiscoveredAllAutoConnectPeripherals]) {
      [central stopScan];
  }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"Failed to connect to peripheral: %@", error);

  [self attemptReconnectForDisconnectedDevices];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {

  NSLog(@"Discovering services");
  [peripheral discoverServices:[[self class] UUIDsFromUUIDStrings:@[RILEYLINK_SERVICE_UUID]
                                              excludingAttributes:peripheral.services]];

  RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];

  NSDictionary *attrs = @{@"peripheral": peripheral,
                          };
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_CONNECTED object:device userInfo:attrs];
  
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  
  if (error) {
    NSLog(@"Disconnection: %@", error);
  }
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  
  attrs[@"peripheral"] = peripheral;
  RileyLinkBLEDevice *device = _devicesById[peripheral.identifier.UUIDString];
  
  [device didDisconnect:error];
  
  if (error) {
    attrs[@"error"] = error;
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:device userInfo:attrs];
  
  [self attemptReconnectForDisconnectedDevices];
}

@end
