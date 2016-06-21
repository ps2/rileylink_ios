//
//  ChangeTimePumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ChangeTimePumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let timestamp: NSDateComponents
    public let oldTimestamp: NSDateComponents

    public var adjustmentInterval: NSTimeInterval {
        return timestamp.date!.timeIntervalSinceDate(oldTimestamp.date!)
    }

    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 14
        
        guard length <= availableData.length else {
            return nil
        }
        
        oldTimestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 9)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeTime",
        ]
    }
}
