//
//  ChangeTimeFormatPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ChangeTimeFormatPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public let timeFormat: String

    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 7
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }

        timeFormat = d(1) == 1 ? "24hr" : "am_pm"
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeTimeFormat",
            "timeFormat": timeFormat,
        ]
    }
}
