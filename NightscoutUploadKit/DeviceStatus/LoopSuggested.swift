//
//  LoopSuggested.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct LoopSuggested {
    let timestamp: NSDate
    let rate: Double
    let duration: NSTimeInterval
    let correction: Double
    let eventualBG: Int
    let reason: String
    let bg: Int
    let tick: Int
    
    public init(timestamp: NSDate, rate: Double, duration: NSTimeInterval, correction: Double = 0, eventualBG: Int, reason: String, bg: Int, tick: Int) {
        self.timestamp = timestamp
        self.rate = rate
        self.duration = duration
        self.correction = correction
        self.eventualBG = eventualBG
        self.reason = reason
        self.bg = bg
        self.tick = tick
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        let tickStr: String
        
        if tick > 0 {
            tickStr = "+\(tick)"
        } else if tick < 0 {
            tickStr = "-\(tick)"
        } else {
            tickStr = "0"
        }
        
        return [
            "timestamp": TimeFormat.timestampStrFromDate(timestamp),
            "rate": rate,
            "duration": duration / 60.0,
            "bg": bg,
            "correction": correction,
            "eventualBG": eventualBG,
            "reason": reason,
            "tick": tickStr,
        ]
    }
}
