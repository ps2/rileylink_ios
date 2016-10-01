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

    public static let RileyLinkDeviceKey = "com.rileylink.RileyLinkKit.RileyLinkDevice"
    public static let RileyLinkRSSIKey = "com.rileylink.RileyLinkKit.RileyLinkRSSI"
    public static let RileyLinkNameKey = "com.rileylink.RileyLinkKit.RileyLinkName"

    public var pumpState: PumpState? {
        didSet {
            for device in _devices {
                device.pumpState = pumpState
            }
        }
    }
    
    public init(pumpState: PumpState?, autoConnectIDs: Set<String>) {
        self.pumpState = pumpState
        
        bleManager.autoConnectIds = autoConnectIDs
        
        NotificationCenter.default.addObserver(self, selector: #selector(discoveredBLEDevice(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_LIST_UPDATED), object: bleManager)
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_DEVICE_CONNECTED), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_DEVICE_DISCONNECTED), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rssiDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_RSSI_CHANGED), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(nameDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_NAME_CHANGED), object: nil)
    }

    public var deviceScanningEnabled: Bool {
        get {
            return bleManager.isScanningEnabled
        }
        set {
            bleManager.isScanningEnabled = newValue
        }
    }

    /// Whether to subscribe devices to a timer characteristic changing every ~60s.
    /// Provides a reliable, external heartbeat for executing periodic tasks.
    public var timerTickEnabled = true {
        didSet {
            for device in _devices {
                device.device.timerTickEnabled = timerTickEnabled
            }
        }
    }

    /// Whether devices should listen for broadcast packets when not running commands
    public var idleListeningEnabled = true {
        didSet {
            for device in _devices {
                if idleListeningEnabled {
                    device.device.enableIdleListening(onChannel: 0)
                } else {
                    device.device.disableIdleListening()
                }
            }
        }
    }
    
    private var _devices: [RileyLinkDevice] = []
    
    public var devices: [RileyLinkDevice] {
        return _devices
    }
    
    public var firstConnectedDevice: RileyLinkDevice? {
        if let index = _devices.index(where: { $0.peripheral.state == .connected }) {
            return _devices[index]
        } else {
            return nil
        }
    }
    
    public func connectDevice(_ device: RileyLinkDevice) {
        bleManager.connect(device.peripheral)
    }
    
    public func disconnectDevice(_ device: RileyLinkDevice) {
        bleManager.disconnectPeripheral(device.peripheral)
    }
    
    private let bleManager = RileyLinkBLEManager()

    // MARK: - RileyLinkBLEManager
    
    @objc private func discoveredBLEDevice(_ note: Notification) {
        if let bleDevice = note.userInfo?["device"] as? RileyLinkBLEDevice {
            bleDevice.timerTickEnabled = timerTickEnabled

            if idleListeningEnabled {
                bleDevice.enableIdleListening(onChannel: 0)
            }

            let device = RileyLinkDevice(bleDevice: bleDevice, pumpState: pumpState)
            
            _devices.append(device)
            
            NotificationCenter.default.post(name: .DeviceManagerDidDiscoverDevice, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device])
            
        }
    }
    
    @objc private func connectionStateDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = _devices.index(where: { $0.peripheral == bleDevice.peripheral }) {
            let device = _devices[index]
            
            NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device])
        }
    }
    
    @objc private func rssiDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = _devices.index(where: { $0.peripheral == bleDevice.peripheral }) {
            let device = _devices[index]
            
            NotificationCenter.default.post(name: .DeviceRSSIDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device, type(of: self).RileyLinkRSSIKey: note.userInfo!["RSSI"]!])
        }
    }

    @objc private func nameDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = _devices.index(where: { $0.peripheral == bleDevice.peripheral }) {
            let device = _devices[index]

            NotificationCenter.default.post(name: .DeviceNameDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device, type(of: self).RileyLinkNameKey: note.userInfo!["Name"]!])
        }
    }
}


extension RileyLinkDeviceManager: CustomDebugStringConvertible {
    public var debugDescription: String {
        var report = [
            "## RileyLinkDeviceManager",
            "timerTickEnabled: \(timerTickEnabled)",
            "idleListeningEnabled: \(idleListeningEnabled)"
        ]

        for device in devices {
            report.append(device.debugDescription)
        }

        return report.joined(separator: "\n\n")
    }
}


extension Notification.Name {
    public static let DeviceManagerDidDiscoverDevice = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.DidDiscoverDeviceNotification")

    public static let DeviceConnectionStateDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.ConnectionStateDidChangeNotification")

    public static let DeviceRSSIDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.RSSIDidChangeNotification")
    public static let DeviceNameDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.NameDidChangeNotification")
}
