//
//  GlucoseEventType.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum GlucoseEventType: UInt8 {
    case dataEnd = 0x01
    case sensorWeakSignal = 0x02
    case sensorCal = 0x03
    case fokko7 = 0x07
    case sensorTimestamp = 0x08
    case batteryChange = 0x0a
    case sensorStatus = 0x0b
    case dateTimeChange = 0x0c
    case sensorSync = 0x0d
    case calBGForGH = 0x0e
    case sensorCalFactor = 0x0f
    case tenSomething = 0x10
    case nineteenSomething = 0x13
    case unknownDataEvent
    case glucoseSensorDataEvent
    
    public var eventType: GlucoseEvent.Type {
        switch self {
        case .dataEnd:
            return DataEndGlucoseEvent.self
        case .sensorWeakSignal:
            return SensorWeakSignalGlucoseEvent.self
        case .sensorCal:
            return SensorCalGlucoseEvent.self
        case .fokko7:
            return Fokko7GlucoseEvent.self
        case .sensorTimestamp:
            return SensorTimestampGlucoseEvent.self
        case .batteryChange:
            return BatteryChangeGlucoseEvent.self
        case .sensorStatus:
            return SensorStatusGlucoseEvent.self
        case .dateTimeChange:
            return DateTimeChangeGlucoseEvent.self
        case .sensorSync:
            return SensorSyncGlucoseEvent.self
        case .calBGForGH:
            return CalBGForGHGlucoseEvent.self
        case .sensorCalFactor:
            return SensorCalFactorGlucoseEvent.self
        case .tenSomething:
            return TenSomethingGlucoseEvent.self
        case .nineteenSomething:
            return NineteenSomethingGlucoseEvent.self
        default:
            if rawValue < 20 {
                return UnknownGlucoseEvent.self
            } else {
                return GlucoseSensorDataGlucoseEvent.self
            }
        }
    }
}
