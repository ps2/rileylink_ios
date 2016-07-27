//
//  UploaderStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class UploaderStatus {
    var batteryPct: Int? = nil
    var name: String
    var timestamp: NSDate
    
    init(name: String, timestamp: NSDate) {
        self.name = name
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["name"] = name
        rval["timestamp"] = timestamp
        
        if let battery = batteryPct {
            rval["battery"] = battery
        }

        return rval
    }
}