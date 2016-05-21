//
//  ChangeSensorRateOfChangeAlertSetupPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ChangeSensorRateOfChangeAlertSetupPumpEvent: PumpEvent {
    public let length: Int
    let timestamp: NSDateComponents
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 12
        
        if length > availableData.length {
            timestamp = NSDateComponents()
            return nil
        }
        
        timestamp = TimeFormat.parse5ByteDate(availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeSensorRateOfChangeAlertSetup",
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
