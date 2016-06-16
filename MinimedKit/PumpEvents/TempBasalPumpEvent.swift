//
//  TempBasalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TempBasalPumpEvent: TimestampedPumpEvent {
    
    public enum RateType : String {
        case Absolute = "absolute"
        case Percent = "percent"
    }
    
    
    public let length: Int
    public let rateType: RateType
    public let rate: Double
    public let timestamp: NSDateComponents
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 8
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        guard length <= availableData.length else {
            return nil
        }
        
        rateType = (d(7) >> 3) == 0 ? .Absolute : .Percent
        if rateType == .Absolute {
            rate = Double(d(1)) / 40.0
        } else {
            rate = Double(d(1))
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "TempBasal",
            "rate": rate,
            "temp": rateType.rawValue,
        ]
    }
}

