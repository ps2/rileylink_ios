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
            for device in devices {
                device.pumpState = pumpState
            }
        }
    }
    
    public init(pumpState: PumpState?, autoConnectIDs: Set<String>) {
        self.pumpState = pumpState

        bleManager = RileyLinkBLEManager(autoConnectIDs: autoConnectIDs)
        
        NotificationCenter.default.addObserver(self, selector: #selector(discoveredBLEDevice(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_DEVICE_CREATED), object: bleManager)
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_DEVICE_CONNECTED), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_DEVICE_DISCONNECTED), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rssiDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_RSSI_CHANGED), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(nameDidChange(_:)), name: NSNotification.Name(rawValue: RILEYLINK_EVENT_NAME_CHANGED), object: nil)
    }

    public func setDeviceScanningEnabled(_ enabled: Bool) {
        bleManager.setScanningEnabled(enabled)
    }

    /// Whether to subscribe devices to a timer characteristic changing every ~60s.
    /// Provides a reliable, external heartbeat for executing periodic tasks.
    public var timerTickEnabled = true {
        didSet {
            for device in devices {
                device.device.timerTickEnabled = timerTickEnabled
            }
        }
    }

    public var idleTimeout = TimeInterval(minutes: 1) {
        didSet {
            for device in devices {
                device.device.idleTimeoutMS = UInt32(idleTimeout.milliseconds)
            }
        }
    }

    /// Whether devices should listen for broadcast packets when not running commands
    public var idleListeningEnabled = true {
        didSet {
            for device in devices {
                if idleListeningEnabled {
                    device.device.enableIdleListening(onChannel: 0)
                } else {
                    device.device.disableIdleListening()
                }
            }
        }
    }

    private(set) public var devices: [RileyLinkDevice] = []

    // When multiple RL's are present, this moves the specified RL to the back of the list
    // so a different RL will be selected by firstConnectedDevice()
    public func deprioritizeDevice(device: RileyLinkDevice) {
        if let index = devices.index(where: { $0.peripheral.identifier == device.peripheral.identifier }) {
            devices.remove(at: index)
            devices.append(device)
        }
    }

    public var firstConnectedDevice: RileyLinkDevice? {
        if let index = devices.index(where: { $0.peripheral.state == .connected }) {
            return devices[index]
        } else {
            return nil
        }
    }
    
    public func connectDevice(_ device: RileyLinkDevice) {
        bleManager.connect(device.device)
    }
    
    public func disconnectDevice(_ device: RileyLinkDevice) {
        bleManager.disconnectDevice(device.device)
    }
    
    private let bleManager: RileyLinkBLEManager

    // MARK: - RileyLinkBLEManager
    
    @objc private func discoveredBLEDevice(_ note: Notification) {
        if let bleDevice = note.userInfo?["device"] as? RileyLinkBLEDevice {
            bleDevice.timerTickEnabled = timerTickEnabled
            bleDevice.idleTimeoutMS = UInt32(idleTimeout.milliseconds)

            if idleListeningEnabled {
                bleDevice.enableIdleListening(onChannel: 0)
            }

            let device = RileyLinkDevice(bleDevice: bleDevice, pumpState: pumpState)
            
            devices.append(device)
            
            NotificationCenter.default.post(name: .DeviceManagerDidDiscoverDevice, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device])
            
        }
    }
    
    @objc private func connectionStateDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = devices.index(where: { $0.peripheral.identifier == bleDevice.peripheral.identifier }) {
            let device = devices[index]
            
            NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device])
        }
    }
    
    @objc private func rssiDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = devices.index(where: { $0.peripheral.identifier == bleDevice.peripheral.identifier }) {
            let device = devices[index]
            
            NotificationCenter.default.post(name: .DeviceRSSIDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device, type(of: self).RileyLinkRSSIKey: note.userInfo!["RSSI"]!])
        }
    }

    @objc private func nameDidChange(_ note: Notification) {
        if let bleDevice = note.object as? RileyLinkBLEDevice,
            let index = devices.index(where: { $0.peripheral.identifier == bleDevice.peripheral.identifier }) {
            let device = devices[index]

            NotificationCenter.default.post(name: .DeviceNameDidChange, object: self, userInfo: [type(of: self).RileyLinkDeviceKey: device, type(of: self).RileyLinkNameKey: note.userInfo!["Name"]!])
        }
    }
}


extension RileyLinkDeviceManager: CustomDebugStringConvertible {
    public var debugDescription: String {
        var report = [
            "## RileyLinkDeviceManager",
            "timerTickEnabled: \(timerTickEnabled)",
            "idleListeningEnabled: \(idleListeningEnabled)",
            "idleTimeout: \(idleTimeout)"
        ]

        for device in devices {
            report.append(String(reflecting: device))
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
