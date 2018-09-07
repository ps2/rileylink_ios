//
//  TempBasalExtraCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 6/6/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TempBasalExtraCommand : MessageBlock {
    
    public let confidenceReminder: Bool
    public let programReminderInterval: TimeInterval
    public let remainingPulses: Double
    public let delayUntilNextPulse: TimeInterval
    public let rateEntries: [RateEntry]

    public let blockType: MessageBlockType = .tempBasalExtra
    
    public var data: Data {
        let reminders = (UInt8(programReminderInterval.minutes) & 0x3f) + (confidenceReminder ? (1<<6) : 0)
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(8 + rateEntries.count * 6),
            reminders,
            0
            ])
        data.appendBigEndian(UInt16(remainingPulses * 10))
        if remainingPulses == 0 {
            data.appendBigEndian(UInt32(delayUntilNextPulse.hundredthsOfMilliseconds) * 10)
        } else {
            data.appendBigEndian(UInt32(delayUntilNextPulse.hundredthsOfMilliseconds))
        }
        for entry in rateEntries {
            data.append(entry.data)
        }
        return data
    }

    public init(encodedData: Data) throws {
        
        let length = encodedData[1]
        let numEntries = (length - 8) / 6
        
        confidenceReminder = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))
        
        remainingPulses = Double(encodedData[4...].toBigEndian(UInt16.self)) / 10.0
        let timerCounter = encodedData[6...].toBigEndian(UInt32.self)
        delayUntilNextPulse = TimeInterval(hundredthsOfMilliseconds: Double(timerCounter))
        var entries = [RateEntry]()
        for entryIndex in (0..<numEntries) {
            let offset = 10 + entryIndex * 6
            let totalPulses = Double(encodedData[offset...].toBigEndian(UInt16.self)) / 10.0
            let timerCounter = encodedData[(offset+2)...].toBigEndian(UInt32.self)
            let delayBetweenPulses = TimeInterval(hundredthsOfMilliseconds: Double(timerCounter))
            entries.append(RateEntry(totalPulses: totalPulses, delayBetweenPulses: delayBetweenPulses))
        }
        rateEntries = entries
    }
    
    public init(confidenceReminder: Bool, programReminderInterval: TimeInterval, remainingPulses: Double, delayUntilNextPulse: TimeInterval, rateEntries: [RateEntry]) {
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        self.remainingPulses = remainingPulses
        self.delayUntilNextPulse = delayUntilNextPulse
        self.rateEntries = rateEntries
    }
    
    public init(rate: Double, duration: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) {
        rateEntries = RateEntry.makeEntries(rate: rate, duration: duration)
        remainingPulses = rateEntries[0].totalPulses
        delayUntilNextPulse = rateEntries[0].delayBetweenPulses
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
    }
}
