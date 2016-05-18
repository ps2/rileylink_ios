//
//  RileyLinkDeviceManager.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit


public class RileyLinkDeviceManager {
    
    public static let DidDiscoverDeviceNotification = "com.rileylink.RileyLinkKit.DidDiscoverDeviceNotification"
    
    public static let ConnectionStateDidChangeNotification = "com.rileylink.RileyLinkKit.ConnectionStateDidChangeNotification"

    public static let RSSIDidChangeNotification = "com.rileylink.RileyLinkKit.RSSIDidChangeNotification"

    public static let RileyLinkDeviceKey = "com.rileylink.RileyLinkKit.RileyLinkDevice"
    public static let RileyLinkRSSIKey = "com.rileylink.RileyLinkKit.RileyLinkRSSI"
    
    public var pumpState: PumpState? {
        didSet {
            for device in _devices {
                device.pumpState = pumpState
            }
        }
    }
    
    public init(pumpState: PumpState?, autoConnectIDs: Set<String>) {
        self.pumpState = pumpState
        
        BLEManager.autoConnectIds = autoConnectIDs
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(discoveredBLEDevice(_:)), name: RILEYLINK_EVENT_LIST_UPDATED, object: BLEManager)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: RILEYLINK_EVENT_DEVICE_CONNECTED, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: RILEYLINK_EVENT_DEVICE_DISCONNECTED, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(rssiDidChange(_:)), name: RILEYLINK_EVENT_RSSI_CHANGED, object: nil)
    }
    
    public var deviceScanningEnabled: Bool {
        get {
            return BLEManager.scanningEnabled
        }
        set {
            BLEManager.scanningEnabled = newValue
        }
    }
    
    public var timerTickEnabled = true {
        didSet {
            for device in _devices {
                device.device.timerTickEnabled = timerTickEnabled
            }
        }
    }
    
    private var _devices: [RileyLinkDevice] = []
    
    public var devices: [RileyLinkDevice] {
        return _devices
    }
    
    public var firstConnectedDevice: RileyLinkDevice? {
        if let index = _devices.indexOf({ $0.peripheral.state == .Connected }) {
            return _devices[index]
        } else {
            return nil
        }
    }
    
    public func connectDevice(device: RileyLinkDevice) {
        BLEManager.connectPeripheral(device.peripheral)
    }
    
    public func disconnectDevice(device: RileyLinkDevice) {
        BLEManager.disconnectPeripheral(device.peripheral)
    }
    
    private let BLEManager = RileyLinkBLEManager()
    
    // MARK: - RileyLinkBLEManager
    
    @objc private func discoveredBLEDevice(note: NSNotification) {
        if let BLEDevice = note.userInfo?["device"] as? RileyLinkBLEDevice {
            BLEDevice.timerTickEnabled = timerTickEnabled
            
            let device = RileyLinkDevice(BLEDevice: BLEDevice, pumpState: pumpState)
            
            _devices.append(device)
            
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.DidDiscoverDeviceNotification, object: self, userInfo: [self.dynamicType.RileyLinkDeviceKey: device])
            
        }
    }
    
    @objc private func connectionStateDidChange(note: NSNotification) {
        if let BLEDevice = note.object as? RileyLinkBLEDevice,
            index = _devices.indexOf({ $0.peripheral == BLEDevice.peripheral }) {
            let device = _devices[index]
            
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ConnectionStateDidChangeNotification, object: self, userInfo: [self.dynamicType.RileyLinkDeviceKey: device])            
        }
    }
    
    @objc private func rssiDidChange(note: NSNotification) {
        if let BLEDevice = note.object as? RileyLinkBLEDevice,
            index = _devices.indexOf({ $0.peripheral == BLEDevice.peripheral }) {
            let device = _devices[index]
            
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.RSSIDidChangeNotification, object: self, userInfo: [self.dynamicType.RileyLinkDeviceKey: device, self.dynamicType.RileyLinkRSSIKey: note.userInfo!["RSSI"]!])
        }
    }
    
}