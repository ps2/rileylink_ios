//
//  PumpAlarmPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class PumpAlarmPumpEvent: PumpEvent {
    public let length: Int
    let timestamp: NSDateComponents
    let rawType: Int
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 9
        
        guard length <= availableData.length else {
            return nil
        }
        
        rawType = Int(availableData[1] as UInt8)
        timestamp = TimeFormat.parse5ByteDate(availableData, offset: 4)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "AlarmPump",
            "rawType": rawType,
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
