//
//  ChangeTempBasalTypePumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/20/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ChangeTempBasalTypePumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let basalType: String
    public let timestamp: NSDateComponents
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 7
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        guard length <= availableData.length else {
            return nil
        }
        
        basalType = d(1) == 1 ? "percent" : "absolute"
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "TempBasal",
            "temp": basalType,
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
