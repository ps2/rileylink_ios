//
//  BatteryStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum BatteryIndicator: String {
    case Absolute = "absolute"
    case Percentage = "percentage"
}

public struct BatteryStatus {
    let percent: Int?
    let voltage: Double?
    let indicator: BatteryIndicator?
    
    public init(percent: Int? = nil, voltage: Double? = nil, indicator: BatteryIndicator? = nil) {
        self.percent = percent
        self.voltage = voltage
        self.indicator = indicator
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        if let percent = percent {
            rval["percent"] = percent
        }
        if let voltage = voltage {
            rval["voltage"] = voltage
        }

        if let indicator = indicator {
            rval["status"] = indicator.rawValue
        }
        
        return rval
    }
}