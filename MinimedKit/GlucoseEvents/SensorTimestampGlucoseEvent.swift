//
//  SensorTimestampGlucoseEvent.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct SensorTimestampGlucoseEvent: ReferenceTimestampedGlucoseEvent {
    public let length: Int
    public let rawData: Data
    public let timestamp: DateComponents
    private let timestampType: String
    
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
        
        switch (d(3) >> 5 & 0b00000011) {
        case 0x00:
            timestampType = "last_rf"
        case 0x01:
            timestampType = "page_end"
        case 0x02:
            timestampType = "gap"
        default:
            timestampType = "unknown"
        }

    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "name": "SensorTimestamp",
            "timestampType": timestampType
        ]
    }
}
