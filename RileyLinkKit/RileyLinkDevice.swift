//
//  RileyLinkDevice.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 4/10/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreBluetooth
import MinimedKit
import RileyLinkBLEKit


public enum RileyLinkDeviceError: Error {
    case configurationError
}


public class RileyLinkDevice {
    
    public static let IdleMessageDataKey = "com.rileylink.RileyLinkKit.RileyLinkDeviceIdleMessageData"

    public internal(set) var pumpState: PumpState?
    
    public var lastIdle: Date? {
        return device.lastIdle
    }
    
    public private(set) var lastTuned: Date?
    
    public private(set) var radioFrequency: Double?

    public private(set) var pumpRSSI: Int?

    public var firmwareVersion: String? {
        var versions = [String]()
        if let fwVersion = device.firmwareVersion {
            versions.append(fwVersion)
        }
        if let fwVersion = device.bleFirmwareVersion {
            versions.append(fwVersion.replacingOccurrences(of: "RileyLink:", with: ""))
        }
        if versions.count > 0 {
            return versions.joined(separator: " / ")
        } else {
            return "Unknown"
        }
    }
    
    public var deviceURI: String {
        return device.deviceURI
    }
    
    public var name: String? {
        return device.name
    }
    
    public var RSSI: Int? {
        return device.rssi?.intValue
    }
    
    public var peripheral: CBPeripheral {
        return device.peripheral
    }
    
    internal init(bleDevice: RileyLinkBLEDevice, pumpState: PumpState?) {
        self.device = bleDevice
        self.pumpState = pumpState
        
        NotificationCenter.default.addObserver(self, selector: #selector(receivedDeviceNotification(_:)), name: nil, object: bleDevice)

        NotificationCenter.default.addObserver(self, selector: #selector(receivedPacketNotification(_:)), name: .PumpOpsSynchronousDidReceivePacket, object: nil)

    }

    // MARK: - Device commands
    
    public func assertIdleListening(force: Bool = false) {
        device.assertIdleListeningForcingRestart(force)
    }
    
    public func syncPumpTime(_ resultHandler: @escaping (Error?) -> Void) {
        if let ops = ops {
            ops.setTime({ () -> DateComponents in
                    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                    return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
                },
                completion: { (error) in
                    if error == nil {
                        ops.pumpState.timeZone = TimeZone.currentFixed
                    }

                    resultHandler(error)
                }
            )
        } else {
            resultHandler(RileyLinkDeviceError.configurationError)
        }
    }
    
    public func tunePump(_ resultHandler: @escaping (Either<FrequencyScanResults, Error>) -> Void) {
        if let ops = ops {
            ops.tuneRadio(for: ops.pumpState.pumpRegion) { (result) in
                self.lastTuned = Date()
                switch result {
                case .success(let scanResults):
                    self.radioFrequency = scanResults.bestFrequency
                case .failure:
                    break
                }
                
                resultHandler(result)
            }
        } else {
            resultHandler(.failure(RileyLinkDeviceError.configurationError))
        }
    }

    public func setCustomName(_ name: String) {
        device.setCustomName(name)
    }
    
    public var ops: PumpOps? {
        if let pumpState = pumpState {
            return PumpOps(pumpState: pumpState, device: device)
        } else {
            return nil
        }
    }
    
    // MARK: -
    
    internal var device: RileyLinkBLEDevice
    
    @objc private func receivedDeviceNotification(_ note: Notification) {
        switch note.name.rawValue {
        case RILEYLINK_IDLE_RESPONSE_RECEIVED:
            if let packet = note.userInfo?["packet"] as? RFPacket, let pumpID = pumpState?.pumpID, let data = packet.data, let message = PumpMessage(rxData: data), message.address.hexadecimalString == pumpID {
                NotificationCenter.default.post(name: .RileyLinkDeviceDidReceiveIdleMessage, object: self, userInfo: [type(of: self).IdleMessageDataKey: data])
                pumpRSSI = Int(packet.rssi)
            }
        case RILEYLINK_EVENT_DEVICE_TIMER_TICK:
            NotificationCenter.default.post(name: .RileyLinkDeviceDidUpdateTimerTick, object: self)
        default:
            break
        }
    }

    @objc private func receivedPacketNotification(_ note: Notification) {
        if let packet = note.userInfo?[PumpOpsSynchronous.PacketKey] as? RFPacket {
            pumpRSSI = Int(packet.rssi)
        }
    }
}


extension RileyLinkDevice: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## RileyLinkDevice",
            "name: \(name ?? "")",
            "RSSI: \(RSSI ?? 0)",
            "lastIdle: \(lastIdle ?? .distantPast)",
            "lastTuned: \(lastTuned ?? .distantPast)",
            "radioFrequency: \(radioFrequency ?? 0)",
            "firmwareVersion: \(firmwareVersion ?? "")",
            "state: \(peripheral.state.description)"
        ].joined(separator: "\n")
    }
}


extension Notification.Name {
    public static let RileyLinkDeviceDidReceiveIdleMessage = NSNotification.Name(rawValue: "com.rileylink.RileyLinkKit.RileyLinkDeviceDidReceiveIdleMessageNotification")

    public static let RileyLinkDeviceDidUpdateTimerTick = NSNotification.Name(rawValue: "com.rileylink.RileyLinkKit.RileyLinkDeviceDidUpdateTimerTickNotification")
}
