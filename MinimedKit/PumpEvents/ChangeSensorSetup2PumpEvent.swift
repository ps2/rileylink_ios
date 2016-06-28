//
//  ChangeSensorSetup2PumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ChangeSensorSetup2PumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        if pumpModel.hasLowSuspend {
            length = 41
        } else {
            length = 37
        }

        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeSensorSetup2",
        ]
    }
}
