//
//  PodCommsSession+LoopKit.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

extension BasalSchedule {
    public init(repeatingScheduleValues: [LoopKit.RepeatingScheduleValue<Double>]) {
        var lastEntryOffset = TimeInterval(hours: 24) // Start at end of day
        let entries = repeatingScheduleValues.reversed().map({ (value) -> BasalScheduleEntry in
            let duration = lastEntryOffset - value.startTime
            lastEntryOffset = value.startTime
            return BasalScheduleEntry(rate: value.value, duration: duration)
        })
        self.init(entries: entries.reversed())
    }
}
