//
//  JournalEntryInsulinMarkerPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct JournalEntryInsulinMarkerPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public let amount: Double
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 8
        
        guard length <= availableData.length else {
            return nil
        }
        
        rawData = availableData[0..<length]
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
        
        let lowBits = rawData[1] as UInt8
        let highBits = rawData[4] as UInt8
        amount = Double((Int(highBits & 0b1100000) << 3) + Int(lowBits)) / 10.0
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "JournalEntryInsulinMarker",
            "amount": amount,
        ]
    }
}
