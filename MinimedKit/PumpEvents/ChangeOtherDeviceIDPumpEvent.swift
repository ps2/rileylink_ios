//
//  ChangeOtherDeviceIDPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ChangeOtherDeviceIDPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let timestamp: NSDateComponents
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 37
        
        guard length <= availableData.length else {
            return nil
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeOtherDeviceID",
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
