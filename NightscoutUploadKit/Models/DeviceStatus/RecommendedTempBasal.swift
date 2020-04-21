//
//  LoopSuggested.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct RecommendedTempBasal {
    typealias RawValue = [String: Any]

    let timestamp: Date
    let rate: Double
    let duration: TimeInterval

    public init(timestamp: Date, rate: Double, duration: TimeInterval) {
        self.timestamp = timestamp
        self.rate = rate
        self.duration = duration
    }

    public var dictionaryRepresentation: [String: Any] {

        var rval = [String: Any]()

        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["rate"] = rate
        rval["duration"] = duration / 60.0
        return rval
    }
    
    init?(rawValue: RawValue) {
        guard
            let timestampStr = rawValue["timestamp"] as? String,
            let timestamp = TimeFormat.dateFromTimestamp(timestampStr),
            let rate = rawValue["rate"] as? Double,
            let durationMinutes = rawValue["duration"] as? Double
        else {
            return nil
        }
        
        self.timestamp = timestamp
        self.rate = rate
        self.duration = TimeInterval(minutes: durationMinutes)
    }
}
