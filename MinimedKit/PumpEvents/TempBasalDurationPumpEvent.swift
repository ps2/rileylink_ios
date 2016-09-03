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
    public let rawData: NSData
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

        rawData = availableData[0..<length]
        
        duration = d(1) * 30
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "TempBasalDuration",
            "duration": duration,
        ]
    }

    public var description: String {
        return String(format: NSLocalizedString("Temporary Basal: %1$d min", comment: "The format string description of a TempBasalDurationPumpEvent. (1: The duration of the temp basal in minutes)"), duration)
    }
}
