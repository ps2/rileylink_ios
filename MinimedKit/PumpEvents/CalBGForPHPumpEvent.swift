//
//  CalBGForPHPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class CalBGForPHPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let timestamp: NSDateComponents
    public let amount: Int
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        length = 7
        
        guard length <= availableData.length else {
            return nil
        }
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
        amount = ((d(6) & 0b10000000) << 1) + d(1)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "CalBGForPH",
            "timestamp": TimeFormat.timestampStr(timestamp),
            "amount": amount,
        ]
    }
}
