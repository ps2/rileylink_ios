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
    
    public struct RateEntry {
        let totalPulses: Double
        let delayBetweenPulses: TimeInterval
        
        public init(rate: Double, duration: TimeInterval) {
            totalPulses = rate * duration.hours / podPulseSize
            delayBetweenPulses = TimeInterval(hours: 1) / rate * podPulseSize
        }
        
        public init(totalPulses: Double, delayBetweenPulses: TimeInterval) {
            self.totalPulses = totalPulses
            self.delayBetweenPulses = delayBetweenPulses
        }

        public var rate: Double {
            return TimeInterval(hours: 1) / delayBetweenPulses * podPulseSize
        }
        
        public var duration: TimeInterval {
            return delayBetweenPulses * Double(totalPulses)
        }
        
        public var data: Data {
            var data = Data()
            data.appendBigEndian(UInt16(totalPulses * 10))
            data.appendBigEndian(UInt32(delayBetweenPulses.hundredthsOfMilliseconds))
            return data
        }
    }

    public let currentEntryIndex: UInt8
    public let remainingPulses: Double
    public let delayUntilNextPulse: TimeInterval
    public let rateEntries: [RateEntry]

    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(8 + rateEntries.count * 6),
            0x40,
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
    
    public init(currentEntryIndex: UInt8, remainingPulses: Double, delayUntilNextPulse: TimeInterval, rateEntries: [RateEntry]) {
        self.currentEntryIndex = currentEntryIndex
        self.remainingPulses = remainingPulses
        self.delayUntilNextPulse = delayUntilNextPulse
        self.rateEntries = rateEntries
    }
    
    public init(schedule: BasalSchedule, scheduleOffset: TimeInterval) {
        self.rateEntries = schedule.entries.map { BasalScheduleExtraCommand.RateEntry(rate: $0.rate, duration: $0.duration) }
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


