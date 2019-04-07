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
    
    public let acknowledgementBeep: Bool
    public let confidenceReminder: Bool
    public let programReminderInterval: TimeInterval
    public let currentEntryIndex: UInt8
    public let remainingPulses: Double
    public let delayUntilNextTenthOfPulse: TimeInterval
    public let rateEntries: [RateEntry]

    public var data: Data {
        let beepOptions = (UInt8(programReminderInterval.minutes) & 0x3f) + (confidenceReminder ? (1<<6) : 0) + (acknowledgementBeep ? (1<<7) : 0)
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(8 + rateEntries.count * 6),
            beepOptions,
            currentEntryIndex
            ])
        data.appendBigEndian(UInt16(round(remainingPulses * 10)))
        data.appendBigEndian(UInt32(round(delayUntilNextTenthOfPulse.milliseconds * 1000)))
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
        
        acknowledgementBeep = encodedData[2] & (1<<7) != 0
        confidenceReminder = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))

        currentEntryIndex = encodedData[3]
        remainingPulses = Double(encodedData[4...].toBigEndian(UInt16.self)) / 10.0
        let timerCounter = encodedData[6...].toBigEndian(UInt32.self)
        delayUntilNextTenthOfPulse = TimeInterval(hundredthsOfMilliseconds: Double(timerCounter))
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
    
    public init(acknowledgementBeep: Bool, confidenceReminder: Bool, programReminderInterval: TimeInterval, currentEntryIndex: UInt8, remainingPulses: Double, delayUntilNextTenthOfPulse: TimeInterval, rateEntries: [RateEntry]) {
        self.acknowledgementBeep = acknowledgementBeep
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        self.currentEntryIndex = currentEntryIndex
        self.remainingPulses = remainingPulses
        self.delayUntilNextTenthOfPulse = delayUntilNextTenthOfPulse
        self.rateEntries = rateEntries
    }
    
    public init(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool, confidenceReminder: Bool, programReminderInterval: TimeInterval) {
        self.acknowledgementBeep = acknowledgementBeep
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        var rateEntries = [RateEntry]()
        
        let mergedSchedule = BasalSchedule(entries: schedule.entries.adjacentEqualRatesMerged())
        for entry in mergedSchedule.durations() {
            rateEntries.append(contentsOf: RateEntry.makeEntries(rate: entry.rate, duration: entry.duration))
        }
        
        self.rateEntries = rateEntries
        let scheduleOffsetNearestSecond = round(scheduleOffset)
        let (entryIndex, entry, duration) = mergedSchedule.lookup(offset: scheduleOffsetNearestSecond)
        self.currentEntryIndex = UInt8(entryIndex)
        let timeRemainingInEntry = duration - (scheduleOffsetNearestSecond - entry.startTime)
        let rate = mergedSchedule.rateAt(offset: scheduleOffsetNearestSecond)
        let pulsesPerHour = round(rate / Pod.pulseSize)
        let timeBetweenPulses = TimeInterval(hours: 1) / pulsesPerHour
        self.delayUntilNextTenthOfPulse = timeRemainingInEntry.truncatingRemainder(dividingBy: (timeBetweenPulses / 10))
        self.remainingPulses = pulsesPerHour * (timeRemainingInEntry-self.delayUntilNextTenthOfPulse) / .hours(1) + 0.1
    }
}
