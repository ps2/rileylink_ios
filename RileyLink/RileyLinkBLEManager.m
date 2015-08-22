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
  NSMutableDictionary *devicesById; // RileyLinkBLEDevices by UUID
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

    devicesById = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark -

- (NSArray*)rileyLinkList {
    return devicesById.allValues;
}

- (RileyLinkBLEDevice *)addPeripheralToDeviceList:(CBPeripheral *)peripheral {
    RileyLinkBLEDevice *d = devicesById[peripheral.identifier.UUIDString];
    if (devicesById[peripheral.identifier.UUIDString] == nil) {
        d = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];
        devicesById[peripheral.identifier.UUIDString] = d;
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
    return [self.autoConnectIds isSubsetOfSet:[NSSet setWithArray:devicesById.allKeys]];
}

#pragma mark -

- (void)startScan {
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:GLUCOSELINK_SERVICE_UUID]] options:NULL];

    NSLog(@"Scanning started (state = %ld)", self.centralManager.state);
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

  [[NSNotificationCenter defaultCenter] postNotificationName:RILEY_LINK_EVENT_LIST_UPDATED object:nil];

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
  [peripheral discoverServices:[[self class] UUIDsFromUUIDStrings:@[GLUCOSELINK_SERVICE_UUID,
                                                                    GLUCOSELINK_BATTERY_SERVICE]
                                              excludingAttributes:peripheral.services]];

  NSDictionary *attrs = @{
                          @"peripheral": peripheral,
                          @"device": devicesById[peripheral.identifier.UUIDString]
                          };
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEY_LINK_EVENT_DEVICE_CONNECTED object:nil userInfo:attrs];
  
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  
  if (error) {
    NSLog(@"Disconnection: %@", error);
  }
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  
  attrs[@"peripheral"] = peripheral;
  RileyLinkBLEDevice *device = devicesById[peripheral.identifier.UUIDString];
  attrs[@"device"] = device;
  
  [device didDisconnect:error];
  
  if (error) {
    attrs[@"error"] = error;
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:RILEY_LINK_EVENT_DEVICE_DISCONNECTED object:nil userInfo:attrs];
  
  [self attemptReconnectForDisconnectedDevices];
}

@end
