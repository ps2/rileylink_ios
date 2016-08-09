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
    let predBGs: [Double]?

    public init(timestamp: NSDate, rate: Double, duration: NSTimeInterval, eventualBG: HKQuantity, bg: HKQuantity, reason: String? = nil, tick: Int? = nil, correction: Double? = nil, predBGs: [HKQuantity]? = nil) {
        // All nightscout data is in mg/dL.
        let unit = HKUnit.milligramsPerDeciliterUnit()

        self.init(
            timestamp: timestamp,
            rate: rate,
            duration: duration,
            eventualBG: Int(eventualBG.doubleValueForUnit(unit)),
            bg: Int(bg.doubleValueForUnit(unit)),
            reason: reason,
            tick: tick,
            correction: correction,
            predBGs: predBGs?.map { $0.doubleValueForUnit(unit) }
        )
    }

    public init(timestamp: NSDate, rate: Double, duration: NSTimeInterval, eventualBG: Int, bg: Int, reason: String? = nil, tick: Int? = nil, correction: Double? = nil, predBGs: [Double]? = nil) {
        self.timestamp = timestamp
        self.rate = rate
        self.duration = duration
        self.eventualBG = eventualBG
        self.bg = bg
        self.reason = reason
        self.tick = tick
        self.correction = correction
        self.predBGs = predBGs
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

        if let predBGs = predBGs {
            rval["predBGs"] = predBGs
        }

        return rval
    }
}
