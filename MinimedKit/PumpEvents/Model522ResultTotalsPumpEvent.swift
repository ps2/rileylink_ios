//
//  Model522ResultTotalsPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class Model522ResultTotalsPumpEvent: PumpEvent {
    public let length: Int
    let timestamp: NSDateComponents
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 44
        
        if length > availableData.length {
            timestamp = NSDateComponents()
            return nil
        }
        
        timestamp = TimeFormat.parse5ByteDate(availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "Model522ResultTotals",
            "timestamp": TimeFormat.timestampStr(timestamp),
        ]
    }
}
