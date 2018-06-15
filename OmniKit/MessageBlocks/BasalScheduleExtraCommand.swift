//
//  BasalScheduleExtraCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 3/30/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalScheduleExtraCommand : MessageBlock {

    public let blockType: MessageBlockType = .basalScheduleExtra
    
    public let confidenceReminder: Bool
    public let programReminderInterval: TimeInterval
    public let currentEntryIndex: UInt8
    public let remainingPulses: Double
    public let delayUntilNextPulse: TimeInterval
    public let rateEntries: [RateEntry]

    public var data: Data {
        let reminders = (UInt8(programReminderInterval.minutes) & 0x3f) + (confidenceReminder ? (1<<6) : 0)
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(8 + rateEntries.count * 6),
            reminders,
            currentEntryIndex
            ])
        data.appendBigEndian(UInt16(remainingPulses * 10))
        data.appendBigEndian(UInt32(delayUntilNextPulse.hundredthsOfMilliseconds))
        for entry in rateEntries {
            data.append(entry.data)
        }
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 14 {
            throw MessageBlockError.notEnoughData
        }
        let length = encodedData[1]
        let numEntries = (length - 8) / 6
        
        confidenceReminder = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))

        currentEntryIndex = encodedData[3]
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
    
    public init(confidenceReminder: Bool, programReminderInterval: TimeInterval, currentEntryIndex: UInt8, remainingPulses: Double, delayUntilNextPulse: TimeInterval, rateEntries: [RateEntry]) {
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        self.currentEntryIndex = currentEntryIndex
        self.remainingPulses = remainingPulses
        self.delayUntilNextPulse = delayUntilNextPulse
        self.rateEntries = rateEntries
    }
    
    public init(schedule: BasalSchedule, scheduleOffset: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) {
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        var rateEntries = [RateEntry]()
        for entry in schedule.entries {
            rateEntries.append(contentsOf: RateEntry.makeEntries(rate: entry.rate, duration: entry.duration))
        }
        self.rateEntries = rateEntries
        let (entryIndex, entry, entryStart) = schedule.lookup(offset: scheduleOffset)
        self.currentEntryIndex = UInt8(entryIndex)
        let timeRemainingInEntry = entry.duration - (scheduleOffset - entryStart)
        let rate = schedule.rateAt(offset: scheduleOffset)
        let pulsesPerHour = rate / podPulseSize
        self.remainingPulses = ceil(timeRemainingInEntry * pulsesPerHour / TimeInterval(hours: 1))
        let timeBetweenPulses = TimeInterval(hours: 1) / pulsesPerHour
        self.delayUntilNextPulse = timeBetweenPulses - scheduleOffset.truncatingRemainder(dividingBy: timeBetweenPulses)
    }
}


