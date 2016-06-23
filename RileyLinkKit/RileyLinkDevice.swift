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


public class RileyLinkDevice {
    
    enum Error: ErrorType {
        case ConfigurationError
    }
    
    public static let DidReceiveIdleMessageNotification = "com.rileylink.RileyLinkKit.RileyLinkDeviceDidReceiveIdleMessageNotification"
    
    public static let IdleMessageDataKey = "com.rileylink.RileyLinkKit.RileyLinkDeviceIdleMessageData"

    public static let DidUpdateTimerTickNotification = "com.rileylink.RileyLinkKit.RileyLinkDeviceDidUpdateTimerTickNotification"
    
    public internal(set) var pumpState: PumpState?
    
    public var lastIdle: NSDate? {
        return device.lastIdle
    }
    
    public private(set) var lastTuned: NSDate?
    
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
        return device.RSSI?.integerValue
    }
    
    public var peripheral: CBPeripheral {
        return device.peripheral
    }
    
    internal init(BLEDevice: RileyLinkBLEDevice, pumpState: PumpState?) {
        self.device = BLEDevice
        self.pumpState = pumpState
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(receivedDeviceNotification(_:)), name: nil, object: BLEDevice)
    }
    
    // MARK: - Device commands
    
    public func assertIdleListening() {
        device.assertIdleListening()
    }
    
    public func syncPumpTime(resultHandler: (ErrorType?) -> Void) {
        if let ops = ops {
            ops.setTime({ () -> NSDateComponents in
                    let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                    return calendar.components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: NSDate())
                },
                completion: { (error) in
                    if error == nil {
                        ops.pumpState.timeZone = NSTimeZone.defaultTimeZone()
                    }

                    resultHandler(error)
                }
            )
        } else {
            resultHandler(Error.ConfigurationError)
        }
    }
    
    public func tunePumpWithResultHandler(resultHandler: (Either<FrequencyScanResults, ErrorType>) -> Void) {
        if let ops = ops {
            ops.tunePump { (result) in
                switch result {
                case .Success(let scanResults):
                    self.lastTuned = NSDate()
                    self.radioFrequency = scanResults.bestFrequency
                case .Failure:
                    break
                }
                
                resultHandler(result)
            }
        } else {
            resultHandler(.Failure(Error.ConfigurationError))
        }
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
    
    @objc private func receivedDeviceNotification(note: NSNotification) {
        switch note.name {
        case RILEYLINK_EVENT_PACKET_RECEIVED:
            if let packet = note.userInfo?["packet"] as? RFPacket, pumpID = pumpState?.pumpID, data = packet.data, message = PumpMessage(rxData: data) where message.address.hexadecimalString == pumpID {
                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.DidReceiveIdleMessageNotification, object: self, userInfo: [self.dynamicType.IdleMessageDataKey: data])
            }
        case RILEYLINK_EVENT_DEVICE_TIMER_TICK:
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.DidUpdateTimerTickNotification, object: self)
        default:
            break
        }
    }
    
}
