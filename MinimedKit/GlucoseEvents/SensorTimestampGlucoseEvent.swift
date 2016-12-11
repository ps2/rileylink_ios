//
//  SensorTimestampGlucoseEvent.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum SensorTimestampType: String {
    case lastRf
    case pageEnd
    case gap
    case unknown
    
    public static func eventType(code: UInt8) -> SensorTimestampType {
        switch code {
        case 0x00:
            return .lastRf
        case 0x01:
            return .pageEnd
        case 0x02:
            return .gap
        default:
            return .unknown
        }
    }
    
}

public struct SensorTimestampGlucoseEvent: GlucoseEvent {
    public let length: Int
    public let rawData: Data
    public let timestamp: DateComponents
    public let timestampType: SensorTimestampType
    
    public init?(availableData: Data, relativeTimestamp: DateComponents) {
        length = 5
        
        guard length <= availableData.count else {
            return nil
        }
        
        func d(_ idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        rawData = availableData.subdata(in: 0..<length)
        timestamp = DateComponents(glucoseEventBytes: availableData.subdata(in: 1..<5))
        timestampType = SensorTimestampType.eventType(code: UInt8(d(3) >> 5) & 0b00000011)

    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "name": "SensorTimestamp",
            "timestampType": timestampType
        ]
    }
}
