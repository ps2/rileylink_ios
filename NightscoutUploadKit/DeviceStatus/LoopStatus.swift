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
        
        rval["timestamp"] = timestamp
        rval["name"] = name
        
        if let iob = iob {
            rval["iob"] = ["iob": iob]
        }
        
        var suggested = [String: AnyObject]()
        
        if let glucose = glucose {
            suggested["bg"] = glucose
        }
        
        if let rate = suggestedRate {
            suggested["rate"] = rate
        }
        
        
        rval["suggested"] = suggested
        
        
        return rval
    }
}

