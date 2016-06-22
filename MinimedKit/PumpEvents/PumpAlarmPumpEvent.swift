//
//  PumpAlarmPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PumpAlarmPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    let rawType: Int
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 9
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        rawType = Int(availableData[1] as UInt8)
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 4)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "AlarmPump",
            "rawType": rawType,
        ]
    }
}
