//
//  UploaderStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct UploaderStatus {

    public let battery: Int?
    public let name: String
    public let timestamp: NSDate
    
    public init(name: String, timestamp: NSDate, battery: Int? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.battery = battery
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["name"] = name
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        
        if let battery = battery {
            rval["battery"] = battery
        }

        return rval
    }
}