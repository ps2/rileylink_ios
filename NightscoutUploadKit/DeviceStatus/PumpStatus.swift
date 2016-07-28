//
//  PumpStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class PumpStatus {
    let clock: NSDate
    let iob: IOBStatus?
    let battery: BatteryStatus?
    var suspended: Bool? = nil
    var reservoir: Double? = nil
    
    public init(clock: NSDate, iob: IOBStatus? = nil, battery: BatteryStatus? = nil, suspended: Bool? = nil, reservoir: Double? = nil) {
        self.clock = clock
        self.iob = iob
        self.battery = battery
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["clock"] = TimeFormat.timestampStrFromDate(clock)
        
        if let battery = battery {
            rval["battery"] = battery.dictionaryRepresentation
        }
        
        if let reservoir = reservoir {
            rval["reservoir"] = reservoir
        }
        
        if let iob = iob {
            rval["iob"] = iob.dictionaryRepresentation
        }
        
        return rval
    }
}