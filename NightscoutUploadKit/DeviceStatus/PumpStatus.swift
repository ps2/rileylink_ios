//
//  PumpStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PumpStatus {
    let clock: NSDate
    let pumpID: String
    let iob: IOBStatus?
    let battery: BatteryStatus?
    let suspended: Bool?
    let bolusing: Bool?
    let reservoir: Double?
    
    public init(clock: NSDate, pumpID: String, iob: IOBStatus? = nil, battery: BatteryStatus? = nil, suspended: Bool? = nil, bolusing: Bool? = nil, reservoir: Double? = nil) {
        self.clock = clock
        self.pumpID = pumpID
        self.iob = iob
        self.battery = battery
        self.suspended = suspended
        self.bolusing = bolusing
        self.reservoir = reservoir
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["clock"] = TimeFormat.timestampStrFromDate(clock)
        rval["pumpID"] = pumpID
        
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