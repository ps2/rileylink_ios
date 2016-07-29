//
//  IOBStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct IOBStatus {
    let iob: Double // basal iob + bolus iob: can be negative
    let basaliob: Double
    let timestamp: NSDate
    
    public init(iob: Double, basaliob: Double, timestamp: NSDate) {
        self.iob = iob
        self.basaliob = basaliob
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "iob": iob,
            "basaliob": basaliob,
            "timestamp": TimeFormat.timestampStrFromDate(timestamp),
        ]
    }
}