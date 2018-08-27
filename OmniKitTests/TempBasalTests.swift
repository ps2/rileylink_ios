//
//  TempBasalTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 6/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import XCTest
@testable import OmniKit

class TempBasalTests: XCTestCase {
    func testSetTempBasalCommand() {
        do {
            // Decode 1a 0e ea2d0a3b 01 007d 01 3840 0002 0002
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0eea2d0a3b01007d01384000020002")!)

            XCTAssertEqual(0xea2d0a3b, cmd.nonce)
            if case SetInsulinScheduleCommand.DeliverySchedule.tempBasal(let secondsRemaining, let firstSegmentPulses, let table) = cmd.deliverySchedule {
                
                XCTAssertEqual(1800, secondsRemaining)
                XCTAssertEqual(2, firstSegmentPulses)
                let entry = table.entries[0]
                XCTAssertEqual(1, entry.segments)
                XCTAssertEqual(2, entry.pulses)
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }

        // Encode
        let cmd = SetInsulinScheduleCommand(nonce: 0xea2d0a3b, tempBasalRate: 0.20, duration: .hours(0.5))
        XCTAssertEqual("1a0eea2d0a3b01007d01384000020002", cmd.data.hexadecimalString)
    }
    
    func testSetTempBasalWithAlternatingPulse() {
        do {
            // 0.05U/hr for 2.5 hours
            // Decode 1a 0e 4e2c2717 01 007f 05 3840 0000 4800
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0e4e2c271701007f05384000004800")!)
            
            XCTAssertEqual(0x4e2c2717, cmd.nonce)
            if case SetInsulinScheduleCommand.DeliverySchedule.tempBasal(let secondsRemaining, let firstSegmentPulses, let table) = cmd.deliverySchedule {
                
                XCTAssertEqual(1800, secondsRemaining)
                XCTAssertEqual(0, firstSegmentPulses)
                XCTAssertEqual(1, table.entries.count)
                XCTAssertEqual(5, table.entries[0].segments)
                XCTAssertEqual(0, table.entries[0].pulses)
                XCTAssertEqual(true, table.entries[0].alternateSegmentPulse)
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = SetInsulinScheduleCommand(nonce: 0x4e2c2717, tempBasalRate: 0.05, duration: .hours(2.5))
        XCTAssertEqual("1a0e4e2c271701007f05384000004800", cmd.data.hexadecimalString)
    }

    func testLargerTempBasalCommand() {
        do {
            // 2.00 U/h for 1.5h
            // Decode 1a 0e 87e8d03a 01 00cb 03 3840 0014 2014
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0e87e8d03a0100cb03384000142014")!)
            
            XCTAssertEqual(0x87e8d03a, cmd.nonce)
            if case SetInsulinScheduleCommand.DeliverySchedule.tempBasal(let secondsRemaining, let firstSegmentPulses, let table) = cmd.deliverySchedule {
                
                XCTAssertEqual(1800, secondsRemaining)
                XCTAssertEqual(0x14, firstSegmentPulses)
                let entry = table.entries[0]
                XCTAssertEqual(3, entry.segments)
                XCTAssertEqual(20, entry.pulses)
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = SetInsulinScheduleCommand(nonce: 0x87e8d03a, tempBasalRate: 2, duration: .hours(1.5))
        XCTAssertEqual("1a0e87e8d03a0100cb03384000142014", cmd.data.hexadecimalString)
    }
    
    func testTempBasalExtremeValues() {
        do {
            // 30 U/h for 12 hours
            // Decode 1a 10 a958c5ad 01 04f5 18 3840 012c f12c 712c
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a10a958c5ad0104f5183840012cf12c712c")!)
            
            XCTAssertEqual(0xa958c5ad, cmd.nonce)
            if case SetInsulinScheduleCommand.DeliverySchedule.tempBasal(let secondsRemaining, let firstSegmentPulses, let table) = cmd.deliverySchedule {
                
                XCTAssertEqual(1800, secondsRemaining)
                XCTAssertEqual(300, firstSegmentPulses)
                XCTAssertEqual(2, table.entries.count)
                let entry1 = table.entries[0]
                XCTAssertEqual(16, entry1.segments)
                XCTAssertEqual(300, entry1.pulses)
                let entry2 = table.entries[1]
                XCTAssertEqual(8, entry2.segments)
                XCTAssertEqual(300, entry2.pulses)
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = SetInsulinScheduleCommand(nonce: 0xa958c5ad, tempBasalRate: 30, duration: .hours(12))
        XCTAssertEqual("1a10a958c5ad0104f5183840012cf12c712c", cmd.data.hexadecimalString)
    }

    func testTempBasalExtraCommand() {
        do {
            // 30 U/h for 0.5 hours
            // Decode 16 0e 7c 00 0bb8 000927c0 0bb8 000927c0
            let cmd = try TempBasalExtraCommand(encodedData: Data(hexadecimalString: "160e7c000bb8000927c00bb8000927c0")!)
            XCTAssertEqual(true, cmd.confidenceReminder)
            XCTAssertEqual(.minutes(60), cmd.programReminderInterval)
            XCTAssertEqual(TimeInterval(seconds: 6), cmd.delayUntilNextPulse)
            XCTAssertEqual(300, cmd.remainingPulses)
            XCTAssertEqual(1, cmd.rateEntries.count)
            let entry = cmd.rateEntries[0]
            XCTAssertEqual(TimeInterval(seconds: 6), entry.delayBetweenPulses)
            XCTAssertEqual(TimeInterval(minutes: 30), entry.duration)
            XCTAssertEqual(30, entry.rate)

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = TempBasalExtraCommand(rate: 30, duration: .hours(0.5), confidenceReminder: true, programReminderInterval: .minutes(60))
        XCTAssertEqual("160e7c000bb8000927c00bb8000927c0", cmd.data.hexadecimalString)
    }

    func testTempBasalExtraCommandExtremeValues() {
        do {
            // 30 U/h for 12 hours
            // Decode 16 14 3c 00 f618 000927c0 f618 000927c0 2328 000927c0
            let cmd = try TempBasalExtraCommand(encodedData: Data(hexadecimalString: "16143c00f618000927c0f618000927c02328000927c0")!)
            XCTAssertEqual(false, cmd.confidenceReminder)
            XCTAssertEqual(.minutes(60), cmd.programReminderInterval)
            XCTAssertEqual(TimeInterval(seconds: 6), cmd.delayUntilNextPulse)
            XCTAssertEqual(6300, cmd.remainingPulses)
            XCTAssertEqual(2, cmd.rateEntries.count)
            let entry = cmd.rateEntries[0]
            XCTAssertEqual(TimeInterval(seconds: 6), entry.delayBetweenPulses)
            XCTAssertEqual(TimeInterval(hours: 10.5), entry.duration)
            XCTAssertEqual(30, entry.rate)
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = TempBasalExtraCommand(rate: 30, duration: .hours(12), confidenceReminder: false, programReminderInterval: .minutes(60))
        XCTAssertEqual("16143c00f618000927c0f618000927c02328000927c0", cmd.data.hexadecimalString)
    }
    
    func testTempBasalExtraCommandExtremeValues2() {
        do {
            // 29.95 U/h for 12 hours
            // Decode  16 14 00 00 f5af 00092ba9 f5af 00092ba9 2319 00092ba9
            let cmd = try TempBasalExtraCommand(encodedData: Data(hexadecimalString: "16140000f5af00092ba9f5af00092ba9231900092ba9")!)
            XCTAssertEqual(false, cmd.confidenceReminder)
            XCTAssertEqual(.minutes(0), cmd.programReminderInterval)
            XCTAssertEqual(TimeInterval(seconds: 6.01001), cmd.delayUntilNextPulse)
            XCTAssertEqual(6289.5, cmd.remainingPulses)
            XCTAssertEqual(2, cmd.rateEntries.count)
            let entry1 = cmd.rateEntries[0]
            let entry2 = cmd.rateEntries[1]
            XCTAssertEqual(TimeInterval(seconds: 6.01001), entry1.delayBetweenPulses, accuracy: .ulpOfOne)
            XCTAssertEqual(TimeInterval(hours: 12), entry1.duration + entry2.duration, accuracy: 1)
            XCTAssertEqual(29.95, entry1.rate, accuracy: 0.025)
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode (note, this produces a different encoding than we saw above, as we split at a different point; we'll test
        //         that the difference ends up with the same result below.
        let cmd = TempBasalExtraCommand(rate: 29.95, duration: .hours(12), confidenceReminder: false, programReminderInterval: .minutes(60))
        XCTAssertEqual("16143c00f61800092ba9f61800092ba922af00092ba9", cmd.data.hexadecimalString)
        
        // Test that our variation on splitting up delivery produces the same overall rate and duration
        do {
            // 29.95 U/h for 12 hours
            // Decode  16 14 3c 00 f618 00092ba9 f618 00092ba9 22af 00092ba9
            let cmd = try TempBasalExtraCommand(encodedData: Data(hexadecimalString: "16140000f5af00092ba9f5af00092ba9231900092ba9")!)
            XCTAssertEqual(false, cmd.confidenceReminder)
            XCTAssertEqual(0, cmd.programReminderInterval)
            XCTAssertEqual(TimeInterval(seconds: 6.01001), cmd.delayUntilNextPulse)
            XCTAssertEqual(6289.5, cmd.remainingPulses)
            XCTAssertEqual(2, cmd.rateEntries.count)
            let entry1 = cmd.rateEntries[0]
            let entry2 = cmd.rateEntries[1]
            XCTAssertEqual(TimeInterval(seconds: 6.01001), entry1.delayBetweenPulses, accuracy: .ulpOfOne)
            XCTAssertEqual(TimeInterval(hours: 12), entry1.duration + entry2.duration, accuracy: 1)
            XCTAssertEqual(29.95, entry1.rate, accuracy: 0.025)
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    
    //    16 14 00 00 f5af 00092ba9 f5af 00092ba9 2319 00092ba9


}
