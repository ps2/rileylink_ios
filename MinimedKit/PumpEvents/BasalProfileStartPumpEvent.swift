//
//  BasalProfileStartPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalProfileStartPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    let rate: Double
    let profileIndex: Int
    let offset: Int
    
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 10
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
        rate = Double(d(8)) / 40.0
        profileIndex = d(1)
        offset = d(7) * 30 * 1000 * 60
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "BasalProfileStart",
            "offset": offset,
            "rate": rate,
            "profileIndex": profileIndex,
        ]
    }
    
}
