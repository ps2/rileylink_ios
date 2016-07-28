//
//  LoopEnacted.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class LoopEnacted {
    let rate: Double
    let duration: NSTimeInterval
    let timestamp: NSDate
    let received: Bool
    
    public init(rate: Double, duration: NSTimeInterval, timestamp: NSDate, received: Bool) {
        self.rate = rate
        self.duration = duration
        self.timestamp = timestamp
        self.received = received
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "rate": rate,
            "duration": duration / 60.0,
            "timestamp": TimeFormat.timestampStrFromDate(timestamp),
            "recieved": received  // [sic]
        ]
    }
}