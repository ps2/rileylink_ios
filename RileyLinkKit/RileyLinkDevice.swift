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
    
    public var firmwareVersion: String? {
        return device.firmwareVersion
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
    }
    
    // MARK: - Device commands
    
    public func assertIdleListening() {
        device.assertIdleListening()
    }
    
    public func syncPumpTime(_ resultHandler: @escaping (Error?) -> Void) {
        if let ops = ops {
            ops.setTime({ () -> DateComponents in
                    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                    return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
                },
                completion: { (error) in
                    if error == nil {
                        ops.pumpState.timeZone = TimeZone.current
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
                switch result {
                case .success(let scanResults):
                    self.lastTuned = Date()
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
        case RILEYLINK_EVENT_PACKET_RECEIVED:
            if let packet = note.userInfo?["packet"] as? RFPacket, let pumpID = pumpState?.pumpID, let data = packet.data, let message = PumpMessage(rxData: data), message.address.hexadecimalString == pumpID {
                NotificationCenter.default.post(name: .RileyLinkDeviceDidReceiveIdleMessage, object: self, userInfo: [type(of: self).IdleMessageDataKey: data])
            }
        case RILEYLINK_EVENT_DEVICE_TIMER_TICK:
            NotificationCenter.default.post(name: .RileyLinkDeviceDidUpdateTimerTick, object: self)
        default:
            break
        }
    }
}


extension Notification.Name {
    public static let RileyLinkDeviceDidReceiveIdleMessage = NSNotification.Name(rawValue: "com.rileylink.RileyLinkKit.RileyLinkDeviceDidReceiveIdleMessageNotification")

    public static let RileyLinkDeviceDidUpdateTimerTick = NSNotification.Name(rawValue: "com.rileylink.RileyLinkKit.RileyLinkDeviceDidUpdateTimerTickNotification")

}
