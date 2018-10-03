//
//  BolusExtraCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BolusExtraCommand : MessageBlock {
    
    public let blockType: MessageBlockType = .bolusExtra
    
    public let confidenceReminder: Bool
    public let programReminderInterval: TimeInterval
    public let units: Double
    public let timeBetweenPulses: TimeInterval
    public let squareWaveUnits: Double
    public let squareWaveDuration: TimeInterval

    // 17 0d 7c 1770 00030d40 0000 00000000
    // 0  1  2  3    5        9    13
    public var data: Data {
        let reminders = (UInt8(programReminderInterval.minutes) & 0x3f) + (confidenceReminder ? (1<<6) : 0)

        var data = Data(bytes: [
            blockType.rawValue,
            0x0d,
            reminders
            ])
        
        data.appendBigEndian(UInt16(units * 200))
        data.appendBigEndian(UInt32(timeBetweenPulses.hundredthsOfMilliseconds))
        
        let pulseCountX10 = UInt16(squareWaveUnits * 200)
        data.appendBigEndian(pulseCountX10)
        
        let timeBetweenExtendedPulses = pulseCountX10 > 0 ? squareWaveDuration / Double(pulseCountX10) : 0
        data.appendBigEndian(UInt32(timeBetweenExtendedPulses.hundredthsOfMilliseconds))
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 15 {
            throw MessageBlockError.notEnoughData
        }
        
        confidenceReminder = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))
        
        units = Double(encodedData[3...].toBigEndian(UInt16.self)) / 200

        let delayCounts = encodedData[5...].toBigEndian(UInt32.self)
        timeBetweenPulses = TimeInterval(hundredthsOfMilliseconds: Double(delayCounts))

        let pulseCountX10 = encodedData[9...].toBigEndian(UInt16.self)
        squareWaveUnits = Double(pulseCountX10) / 200
        
        let intervalCounts = encodedData[5...].toBigEndian(UInt32.self)
        let timeBetweenExtendedPulses = TimeInterval(hundredthsOfMilliseconds: Double(intervalCounts))
        squareWaveDuration = timeBetweenExtendedPulses * Double(pulseCountX10) / 10
    }
    
    public init(confidenceReminder: Bool = false, programReminderInterval: TimeInterval = 0, units: Double, timeBetweenPulses: TimeInterval = 2, squareWaveUnits: Double = 0.0, squareWaveDuration: TimeInterval = 0) {
        self.confidenceReminder = confidenceReminder
        self.programReminderInterval = programReminderInterval
        self.units = units
        self.timeBetweenPulses = timeBetweenPulses
        self.squareWaveUnits = squareWaveUnits
        self.squareWaveDuration = squareWaveDuration
    }
}
