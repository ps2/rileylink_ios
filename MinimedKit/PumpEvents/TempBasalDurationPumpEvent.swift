//
//  TempBasalDurationPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/20/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TempBasalDurationPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let duration: Int
    public let timestamp: NSDateComponents
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 7
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        guard length <= availableData.length else {
            return nil
        }
        
        duration = d(1) * 30
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "TempBasal",
            "duration": duration,
        ]
    }
}
