//
//  BatteryStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BatteryStatus {
    let percent: Int?
    let voltage: Double?
    let status: String
    
    public init(percent: Int? = nil, voltage: Double? = nil, status: String = "normal") {
        self.percent = percent
        self.voltage = voltage
        self.status = status
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        if let percent = percent {
            rval["percent"] = percent
        }
        if let voltage = voltage {
            rval["voltage"] = voltage
        }
        rval["status"] = status
        
        return rval
    }
}