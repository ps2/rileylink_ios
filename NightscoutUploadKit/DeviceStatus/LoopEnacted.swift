//
//  LoopEnacted.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct LoopEnacted {
    let rate: Double
    let duration: NSTimeInterval
    let timestamp: NSDate
    let received: Bool
    let predBGs: PredictedBG?
    
    public init(rate: Double, duration: NSTimeInterval, timestamp: NSDate, received: Bool, predBGs: PredictedBG? = nil) {
        self.rate = rate
        self.duration = duration
        self.timestamp = timestamp
        self.received = received
        self.predBGs = predBGs
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["rate"] = rate
        rval["duration"] = duration / 60.0
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["recieved"] = received  // [sic]

        if let predBGs = predBGs {
            rval["predBGs"] = predBGs.dictionaryRepresentation
        }
        return rval
    }
}