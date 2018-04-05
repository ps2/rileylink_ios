//
//  BasalScheduleTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 4/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class BasalScheduleTests: XCTestCase {
    func testSetBasalScheduleCommand() {
        do {
            // Decode 1a 12 77a05551 00 0062 2b 1708 0000 f800 f800 f800
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a1277a055510000622b17080000f800f800f800")!)
            
            XCTAssertEqual(0x77a05551, cmd.nonce)
            if case SetInsulinScheduleCommand.DeliverySchedule.basalSchedule(let currentSegment, let secondsRemaining, let pulsesRemaining, let table) = cmd.deliverySchedule {
                XCTAssertEqual(0x2b, currentSegment)
                XCTAssertEqual(737, secondsRemaining)
                XCTAssertEqual(0, pulsesRemaining)
                XCTAssertEqual(3, table.entries.count)
            } else {
                XCTFail("Expected ScheduleEntry.basalSchedule type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let scheduleEntry = BasalTableEntry(segments: 16, pulses: 0, alternateSegmentPulse: true)
        let table = BasalDeliveryTable(entries: [scheduleEntry, scheduleEntry, scheduleEntry])
        let deliverySchedule = SetInsulinScheduleCommand.DeliverySchedule.basalSchedule(currentSegment: 0x2b, secondsRemaining: 737, pulsesRemaining: 0, table: table)
        let cmd = SetInsulinScheduleCommand(nonce: 0x77a05551, deliverySchedule: deliverySchedule)
        XCTAssertEqual("1a1277a055510000622b17080000f800f800f800", cmd.data.hexadecimalString)
    }
    
    func testBasalScheduleCommandFromSchedule() {
        // Encode from schedule
        let entry = BasalScheduleEntry(rate: 0.05, duration: .hours(24))
        let schedule = BasalSchedule(entries: [entry])
        
        let cmd = SetInsulinScheduleCommand(nonce: 0x01020304, basalSchedule: schedule, scheduleOffset: .hours(8.25))
        
        XCTAssertEqual(0x01020304, cmd.nonce)
        if case SetInsulinScheduleCommand.DeliverySchedule.basalSchedule(let currentSegment, let secondsRemaining, let pulsesRemaining, let table) = cmd.deliverySchedule {
            XCTAssertEqual(16, currentSegment)
            XCTAssertEqual(UInt16(TimeInterval(minutes: 15)), secondsRemaining)
            XCTAssertEqual(0, pulsesRemaining)
            XCTAssertEqual(3, table.entries.count)
            let tableEntry = table.entries[0]
            XCTAssertEqual(true, tableEntry.alternateSegmentPulse)
            XCTAssertEqual(0, tableEntry.pulses)
            XCTAssertEqual(16, tableEntry.segments)
        } else {
            XCTFail("Expected ScheduleEntry.basalSchedule type")
        }
        XCTAssertEqual("1a1201020304000064101c200000f800f800f800", cmd.data.hexadecimalString)
    }

    
    func testBasalScheduleExtraCommand() {
        do {
            // Decode 130e40 00 1aea 001e8480 3840005b8d80
            
            let cmd = try BasalScheduleExtraCommand(encodedData: Data(hexadecimalString: "130e40001aea001e84803840005b8d80")!)
            
            XCTAssertEqual(0, cmd.currentEntryIndex)
            XCTAssertEqual(689, cmd.remainingPulses)
            XCTAssertEqual(TimeInterval(seconds: 20), cmd.delayUntilNextPulse)
            XCTAssertEqual(1, cmd.rateEntries.count)
            let entry = cmd.rateEntries[0]
            XCTAssertEqual(TimeInterval(seconds: 60), entry.delayBetweenPulses)
            XCTAssertEqual(1440, entry.totalPulses)
            XCTAssertEqual(3.0, entry.rate)
            XCTAssertEqual(TimeInterval(hours: 24), entry.duration)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let scheduleEntry = BasalScheduleExtraCommand.RateEntry(rate: 3.0, duration: TimeInterval(hours: 24))
        let cmd = BasalScheduleExtraCommand.init(currentEntryIndex: 0, remainingPulses: 689, delayUntilNextPulse: TimeInterval(seconds: 20), rateEntries: [scheduleEntry])
        XCTAssertEqual("130e40001aea001e84803840005b8d80", cmd.data.hexadecimalString)
    }
    
    func testBasalScheduleExtraCommandFromSchedule() {
        // Encode from schedule
        let entry = BasalScheduleEntry(rate: 0.05, duration: .hours(24))
        let schedule = BasalSchedule(entries: [entry])
        
        let cmd = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: .hours(8.25))
        
        XCTAssertEqual(0, cmd.currentEntryIndex)
        XCTAssertEqual(16, cmd.remainingPulses)
        XCTAssertEqual(TimeInterval(minutes: 45), cmd.delayUntilNextPulse)
        XCTAssertEqual(1, cmd.rateEntries.count)
        let rateEntry = cmd.rateEntries[0]
        XCTAssertEqual(TimeInterval(minutes: 60), rateEntry.delayBetweenPulses)
        XCTAssertEqual(24, rateEntry.totalPulses, accuracy: 0.001)
        XCTAssertEqual(0.05, rateEntry.rate)
        XCTAssertEqual(TimeInterval(hours: 24), rateEntry.duration, accuracy: 0.001)
    }
}

