//
//  BasalSchedule.swift
//  OmniKit
//
//  Created by Pete Schwamb on 4/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalScheduleEntry {
    let rate: Double
    let duration: TimeInterval
    
    public init(rate: Double, duration: TimeInterval) {
        self.rate = rate
        self.duration = duration
    }
}

// A basal schedule starts at midnight and should contain 24 hours worth of entries
public struct BasalSchedule {
    let entries: [BasalScheduleEntry]
    
    public func rateAt(offset: TimeInterval) -> Double {
        let (_, entry, _) = lookup(offset: offset)
        return entry.rate
    }

    func lookup(offset: TimeInterval) -> (Int, BasalScheduleEntry, TimeInterval) {
        guard offset > 0 && offset < .hours(24) else {
            fatalError("Schedule offset out of bounds")
        }
        
        var start: TimeInterval = 0
        for (index, entry) in entries.enumerated() {
            let end = start + entry.duration
            if end > offset {
                return (index, entry, start)
            }
            start = end
        }
        fatalError("Schedule incomplete")
    }
    
    public init(entries: [BasalScheduleEntry]) {
        self.entries = entries
    }
}
