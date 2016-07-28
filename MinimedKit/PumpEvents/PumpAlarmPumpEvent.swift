//
//  PumpAlarmPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpAlarmType: Int {
    case BatteryOutLimitExceeded = 3
    case NoDelivery              = 4
    case BatteryDepleted         = 5
    case DeviceReset             = 16
    case ReprogramError          = 61
    case EmptyReservoir          = 62
    case UnknownType             = -1
}

public struct PumpAlarmPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public let alarmType: PumpAlarmType
    public let rawType: Int
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 9
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        rawType = Int(availableData[1] as UInt8)
        
        if let alarmType = PumpAlarmType(rawValue: rawType) {
            self.alarmType = alarmType
        } else {
            self.alarmType = .UnknownType
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 4)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        let typeDescription: String
        
        if self.alarmType == .UnknownType {
            typeDescription = "Device Alarm(\(rawType))"
        } else {
            typeDescription = "\(self.alarmType)"
        }
        
        return [
            "_type": "AlarmPump",
            "rawType": rawType,
            "alarm": typeDescription,
        ]
    }
}
