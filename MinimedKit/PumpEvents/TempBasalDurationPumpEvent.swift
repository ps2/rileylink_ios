//
//  TempBasalDurationPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/20/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class TempBasalDurationPumpEvent: PumpEvent {
    public let length: Int
    public let duration: Int
    let timestamp: NSDateComponents
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 7
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        if length > availableData.length {
            timestamp = NSDateComponents()
            duration = 0
            return nil
        }
        
        duration = d(1) * 30
        timestamp = TimeFormat.parse5ByteDate(availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "TempBasal",
            "duration": duration,
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
