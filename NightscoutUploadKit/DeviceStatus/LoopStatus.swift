//
//  LoopStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class LoopStatus {
    var name: String
    var timestamp: NSDate
    
    var glucose: Int? = nil
    var iob: Double? = nil
    var iobTimestamp: NSDate? = nil
    var eventualBG: Int? = nil
    var suggestedRate: Double? = nil
    var suggestedDuration: NSTimeInterval? = nil
    var enactedRate: Double? = nil
    var enactedDuration: NSTimeInterval? = nil
    var suggestedBolus: Double? = nil
    var reason: String? = nil
    
    init(name: String, timestamp: NSDate) {
        self.name = name
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["name"] = name
        
        // IOB
        var iobDict = [String: AnyObject]()
        if let iob = iob {
            iobDict["iob"] = iob
        }
        if let iobTimestamp = iobTimestamp {
            iobDict["timestamp"] = TimeFormat.timestampStrFromDate(iobTimestamp)
        }
        rval["iob"] = iobDict
        
        
        // Suggested
        var suggested = [String: AnyObject]()
        if let glucose = glucose {
            suggested["bg"] = glucose
        }
        if let rate = suggestedRate {
            suggested["rate"] = rate
        }
        if let eventualBG = eventualBG {
            suggested["eventualBG"] = eventualBG
        }
        rval["suggested"] = suggested
        
        // Enacted
        var enacted = [String: AnyObject]()
        if let rate = enactedRate {
            enacted["rate"] = rate
        }
        if let duration = enactedDuration {
            enacted["duration"] = duration
        }
        rval["enacted"] = enacted
        return rval
    }
}

