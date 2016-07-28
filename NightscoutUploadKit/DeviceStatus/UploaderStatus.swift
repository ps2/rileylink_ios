//
//  UploaderStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class UploaderStatus {
    public var batteryPct: Int? = nil
    
    public let name: String
    public let timestamp: NSDate
    
    public init(name: String, timestamp: NSDate) {
        self.name = name
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["name"] = name
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        
        if let battery = batteryPct {
            rval["battery"] = battery
        }

        return rval
    }
}