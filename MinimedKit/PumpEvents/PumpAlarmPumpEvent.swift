//
//  PumpAlarmPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpAlarmType {
    case BatteryOutLimitExceeded
    case NoDelivery             
    case BatteryDepleted
    case AutoOff
    case DeviceReset            
    case ReprogramError         
    case EmptyReservoir         
    case UnknownType(rawType: UInt8)

    init(rawType: UInt8) {
        switch rawType {
        case 3:
            self = .BatteryOutLimitExceeded
        case 4:
            self = .NoDelivery
        case 5:
            self = .BatteryDepleted
        case 6:
            self = .AutoOff 
        case 16:
            self = .DeviceReset
        case 61:
            self = .ReprogramError
        case 62:
            self = .EmptyReservoir
        default:
            self = .UnknownType(rawType: rawType)
        }
    }
}

public struct PumpAlarmPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public let alarmType: PumpAlarmType

    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 9
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        alarmType = PumpAlarmType(rawType: availableData[1] as UInt8)
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 4)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {

        return [
            "_type": "AlarmPump",
            "alarm": "\(self.alarmType)",
        ]
    }
}
