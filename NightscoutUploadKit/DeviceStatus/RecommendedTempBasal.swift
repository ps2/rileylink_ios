//
//  LoopSuggested.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct RecommendedTempBasal {
    let timestamp: NSDate
    let rate: Double
    let duration: NSTimeInterval

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["rate"] = rate
        rval["duration"] = duration / 60.0
        return rval
    }
}
