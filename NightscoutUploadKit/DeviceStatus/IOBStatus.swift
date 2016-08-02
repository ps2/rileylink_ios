//
//  IOBStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct IOBStatus {
    let iob: Double? // basal iob + bolus iob: can be negative
    let basaliob: Double? // does not include bolus iob
    let timestamp: NSDate
    
    public init(iob: Double?, basaliob: Double?, timestamp: NSDate) {
        self.iob = iob
        self.basaliob = basaliob
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)

        if let iob = iob {
            rval["iob"] = iob
        }

        if let basaliob = basaliob {
            rval["basaliob"] = basaliob
        }

        return rval
    }
}