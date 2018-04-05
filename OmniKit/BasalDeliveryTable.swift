//
//  BasalDeliveryTable.swift
//  OmniKit
//
//  Created by Pete Schwamb on 4/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalTableEntry {
    let segments: Int
    let pulses: Int
    let alternateSegmentPulse: Bool
    
    public init(encodedData: Data) {
        segments = Int(encodedData[0] >> 4) + 1
        pulses = Int(encodedData[1])
        alternateSegmentPulse = (encodedData[0] >> 3) & 0x1 == 1
    }
    
    public init(segments: Int, pulses: Int, alternateSegmentPulse: Bool) {
        self.segments = segments
        self.pulses = pulses
        self.alternateSegmentPulse = alternateSegmentPulse
    }
    
    public var data: Data {
        return Data(bytes: [
            UInt8((segments - 1) << 4) + UInt8((alternateSegmentPulse ? 1 : 0) << 3),
            UInt8(pulses)
            ])
    }
    
    public func totalPulses() -> UInt16 {
        return UInt16(pulses) * UInt16(segments) + UInt16(alternateSegmentPulse ? segments / 2 : 0)
    }
}

public struct BasalDeliveryTable {
    static let segmentDuration: TimeInterval = .minutes(30)
    
    let entries: [BasalTableEntry]
    
    public init(entries: [BasalTableEntry]) {
        self.entries = entries
    }
    
    public init(schedule: BasalSchedule) {
        var tableEntries = [BasalTableEntry]()
        for entry in schedule.entries {
            let pulsesPerSegment = entry.rate * BasalDeliveryTable.segmentDuration / TimeInterval(hours: 1) / podPulseSize
            let alternateSegmentPulse = pulsesPerSegment - floor(pulsesPerSegment) > 0
            var remaining = Int(entry.duration / .minutes(30))
            while remaining > 0 {
                let segments = min(remaining, 16)
                let tableEntry = BasalTableEntry(segments: segments, pulses: Int(pulsesPerSegment), alternateSegmentPulse: alternateSegmentPulse)
                tableEntries.append(tableEntry)
                remaining -= segments
            }
        }
        self.entries = tableEntries
    }
}
