//
//  SensorCalGlucoseEvent.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct SensorCalGlucoseEvent : RelativeTimestampedGlucoseEvent {
    public let length: Int
    public let rawData: Data
    public let waiting: String
    public var timestamp: DateComponents
    
    public init?(availableData: Data, pumpModel: PumpModel) {
        length = 2
        
        guard length <= availableData.count else {
            return nil
        }
        
        func d(_ idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        rawData = availableData.subdata(in: 0..<length)
        waiting = d(1) == 1 ? "waiting" : "meter_bg_now"
        timestamp = DateComponents()
    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "name": "SensorCal",
        ]
    }
}


