//
//  PumpStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class PumpStatus {
    var batteryPct: Int? = nil
    var batteryStatus: String? = nil
    var batteryVoltage: Double? = nil
    var timestamp: NSDate? = nil
    var status: String? = nil
    var suspended: Bool? = nil
    var bolusIOB: Double? = nil
    var reservoirRemainingUnits: Double? = nil
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        var batteryDict = [String: AnyObject]()
        
        if let batteryPct = batteryPct {
            batteryDict["percent"] = batteryPct
        }
        if let batteryStatus = batteryStatus {
            batteryDict["status"] = batteryStatus
        }
        if let batteryVoltage = batteryVoltage {
            batteryDict["voltage"] = batteryVoltage
        }
        
        rval["battery"] = batteryDict
        
        let pumpDateStr: String?
        
        if let timestamp = timestamp {
            pumpDateStr = TimeFormat.timestampStrFromDate(timestamp)
            rval["clock"] = pumpDateStr
        } else {
            pumpDateStr = nil
        }
        
        if let reservoir = reservoirRemainingUnits {
            rval["reservoir"] = reservoir
        }
        
        // Pump's idea of IOB
        if let iob = bolusIOB {
            var iobDict = [String: AnyObject]()
            iobDict["timestamp"] = pumpDateStr
            iobDict["bolusiob"] = iob
            rval["iob"] = iobDict
        }
        
        return rval
    }

}