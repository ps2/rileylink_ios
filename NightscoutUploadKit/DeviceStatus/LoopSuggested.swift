//
//  LoopSuggested.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import HealthKit

public struct LoopSuggested {
    let timestamp: NSDate
    let rate: Double
    let duration: NSTimeInterval
    let eventualBG: Int
    let bg: Int
    let reason: String?
    let tick: Int?
    let correction: Double?

    public init(timestamp: NSDate, rate: Double, duration: NSTimeInterval, eventualBG: HKQuantity, bg: HKQuantity, reason: String? = nil, tick: Int? = nil, correction: Double? = nil) {

        // BG values in nightscout are in mg/dL.
        let unit = HKUnit.milligramsPerDeciliterUnit()

        self.timestamp = timestamp
        self.rate = rate
        self.duration = duration
        self.eventualBG = Int(eventualBG.doubleValueForUnit(unit))
        self.bg = Int(bg.doubleValueForUnit(unit))
        self.reason = reason
        self.tick = tick
        self.correction = correction
    }

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)

        if let tick = tick {
            let tickStr: String
            if tick > 0 {
                tickStr = "+\(tick)"
            } else if tick < 0 {
                tickStr = "-\(tick)"
            } else {
                tickStr = "0"
            }
            rval["tick"] = tickStr
        }

        rval["rate"] = rate
        rval["duration"] = duration / 60.0
        rval["bg"] = bg
        rval["eventualBG"] = eventualBG

        if let reason = reason {
            rval["reason"] = reason
        }

        if let correction = correction {
            rval["correction"] = correction
        }

        return rval
    }
}
