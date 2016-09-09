//
//  DailyTotal515PumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 9/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct DailyTotal515PumpEvent: PumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 38
        
        guard length <= availableData.length else {
            return nil
        }
        
        rawData = availableData[0..<length]
        
        timestamp = NSDateComponents(pumpEventBytes: availableData[1..<3])
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "DailyTotal515",
        ]
    }
}
