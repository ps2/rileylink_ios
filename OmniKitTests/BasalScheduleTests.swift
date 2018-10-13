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
    
    func testBasalTableEntry() {
        let entry = BasalTableEntry(segments: 2, pulses: 300, alternateSegmentPulse: false)
        // $01 $2c $01 $2c = 1 + 44 + 1 + 44 = 90 = $5a
        XCTAssertEqual(0x5a, entry.checksum())
        
        let entry2 = BasalTableEntry(segments: 2, pulses: 260, alternateSegmentPulse: true)
        // $01 $04 $01 $04 = 1 + 4 + 1 + 5 = 1 = $0b
        XCTAssertEqual(0x0b, entry2.checksum())
    }
    
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
        let entry = BasalScheduleEntry(rate: 0.05, startTime: 0)
        let schedule = BasalSchedule(entries: [entry])
        
        let cmd = SetInsulinScheduleCommand(nonce: 0x01020304, basalSchedule: schedule, scheduleOffset: .hours(8.25))
        
        XCTAssertEqual(0x01020304, cmd.nonce)
        if case SetInsulinScheduleCommand.DeliverySchedule.basalSchedule(let currentSegment, let secondsRemaining, let pulsesRemaining, let table) = cmd.deliverySchedule {
            XCTAssertEqual(16, currentSegment)
            XCTAssertEqual(UInt16(TimeInterval(minutes: 15)), secondsRemaining)
            XCTAssertEqual(1, pulsesRemaining)
            XCTAssertEqual(3, table.entries.count)
            let tableEntry = table.entries[0]
            XCTAssertEqual(true, tableEntry.alternateSegmentPulse)
            XCTAssertEqual(0, tableEntry.pulses)
            XCTAssertEqual(16, tableEntry.segments)
        } else {
            XCTFail("Expected ScheduleEntry.basalSchedule type")
        }
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp napp
        // 1a 12 01020304 00 0065 10 1c20 0001 f800 f800 f800
        XCTAssertEqual("1a1201020304000065101c200001f800f800f800", cmd.data.hexadecimalString)
    }

    
    func testBasalScheduleExtraCommand() {
        do {
            // Decode 130e40 00 1aea 001e8480 3840005b8d80
            
            let cmd = try BasalScheduleExtraCommand(encodedData: Data(hexadecimalString: "130e40001aea001e84803840005b8d80")!)
            
            XCTAssertEqual(true, cmd.confidenceReminder)
            XCTAssertEqual(0, cmd.programReminderInterval)
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
        let rateEntries = RateEntry.makeEntries(rate: 3.0, duration: TimeInterval(hours: 24))
        let cmd = BasalScheduleExtraCommand(confidenceReminder: true, programReminderInterval: 0, currentEntryIndex: 0, remainingPulses: 689, delayUntilNextPulse: TimeInterval(seconds: 20), rateEntries: rateEntries)


        XCTAssertEqual("130e40001aea001e84803840005b8d80", cmd.data.hexadecimalString)
    }
    
    func testBasalScheduleExtraCommandFromSchedule() {
        // Encode from schedule
        let entry = BasalScheduleEntry(rate: 0.05, startTime: 0)
        let schedule = BasalSchedule(entries: [entry])
        
        let cmd = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: .hours(8.25), confidenceReminder: true, programReminderInterval: 60)
        
        XCTAssertEqual(true, cmd.confidenceReminder)
        XCTAssertEqual(60, cmd.programReminderInterval)
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
    
    func testBasalExtraEncoding() {
        // Encode
        
        let schedule = BasalSchedule(entries: [
            BasalScheduleEntry(rate: 1.05, startTime: 0),
            BasalScheduleEntry(rate: 0.9, startTime: .hours(10.5)),
            BasalScheduleEntry(rate: 1, startTime: .hours(18.5))
            ])
        
        let hh = 0x2e
        let ssss = 0x1be8
        let xxxxxxxx = 0x00a7d8c0
        let offset = TimeInterval(minutes: Double((hh + 1) * 30)) - TimeInterval(seconds: Double(ssss / 8)) - TimeInterval(xxxxxxxx % 100000) / 100000
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp napp
        // 1a 14 0d6612db 00 0310 2e 1be8 0005 f80a 480a f009 a00a

        let cmd1 = SetInsulinScheduleCommand(nonce: 0x0d6612db, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a140d6612db0003102e1be80005f80a480af009a00a", cmd1.data.hexadecimalString)

        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ YYYY ZZZZZZZZ YYYY ZZZZZZZZ
        // 13 1a 40 02 0096 00a7d8c0 089d 01059449 05a0 01312d00 044c 0112a880  * PDM
        // 13 1a 40 02 0096 0107fa20 089d 01059449 05a0 01312d00 044c 0112a880
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("131a4002009600a7d8c0089d0105944905a001312d00044c0112a880", cmd2.data.hexadecimalString) // PDM
    }
    
    func checkBasalScheduleExtraCommandDataWithLessPrecision(_ data: Data, _ expected: Data, line: UInt = #line) {
        // The XXXXXXXX is in thousands of a millisecond. Since we use TimeIntervals (floating point) for recreating the offset,
        // we can have small errors in reproducing the the encoded output, which we really don't care about.
        let xxxxxxxx1 = data[6...].toBigEndian(UInt32.self)
        let xxxxxxxx2 = expected[6...].toBigEndian(UInt32.self)
        XCTAssertEqual(xxxxxxxx1, xxxxxxxx2, line: line)
    }

    func testBasalExtraEncoding2() {
        // Encode
        
        let schedule = BasalSchedule(entries: [
            BasalScheduleEntry(rate: 1.05, startTime: 0),
            BasalScheduleEntry(rate: 0.55, startTime: .hours(8.5)),
            BasalScheduleEntry(rate: 0.90, startTime: .hours(9)),
            BasalScheduleEntry(rate: 1.15, startTime: .hours(23.5))
            ])
        
        let hh = 0x01
        let ssss = 0x2948
        let xxxxxxxx = 0x00b8e008
        let offset = TimeInterval(minutes: Double((hh + 1) * 30)) - TimeInterval(seconds: Double(ssss / 8)) - TimeInterval(xxxxxxxx % 100000) / 100000
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp napp napp napp
        // 1a 18 671ab0b2 00 0240 01 2948 0007 f80a 000a 0005 f009 c009 000b
        
        let cmd1 = SetInsulinScheduleCommand(nonce: 0x671ab0b2, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a18671ab0b20002400129480007f80a000a0005f009c009000b", cmd1.data.hexadecimalString)
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ YYYY ZZZZZZZZ YYYY ZZZZZZZZ YYYY ZZZZZZZZ
        // 13 20 00 0006 7c 00b8e008 06f9 01059449 0037 01f360e8 0a32 01312d00 0073 00eed54d
        
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: false, programReminderInterval: 0)
        XCTAssertEqual("13200000067c00b8e00806f901059449003701f360e80a3201312d00007300eed54d", cmd2.data.hexadecimalString) // PDM
        //checkBasalScheduleExtraCommandDataWithLessPrecision(Data(hexadecimalString: "13200000067c00b8e00806f901059449003701f360e80a3201312d00007300eed54d")!, cmd2.data)
    }
    
    func testBasalExtraEncoding3() {
        // Encode
        
        let schedule = BasalSchedule(entries: [
            BasalScheduleEntry(rate: 1.05, startTime: 0),
            BasalScheduleEntry(rate: 0.55, startTime: .hours(8.5)),
            BasalScheduleEntry(rate: 0.90, startTime: .hours(9)),
            BasalScheduleEntry(rate: 1.15, startTime: .hours(23.5))
            ])
        
        let hh = 0x01      // 00:30, rate = 1.05
        let ssss = 0x19f8  // 831s left, 13m 51s
        // hh/ssss offset =
        let xxxxxxxx = 0x00def8a1
        let offset = TimeInterval(minutes: Double((hh + 1) * 30)) - TimeInterval(seconds: Double(ssss / 8)) - TimeInterval(xxxxxxxx % 100000) / 100000

        // 1a 18 6a51490b 00 02dd 01 19f8 0004 f80a 000a 0005 f009 c009 000b 13 20 00 0006 5e 00def8a1 06f9 01059449 0037 01f360e8 0a32 01312d00 0073

        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp napp napp napp
        // 1a 18 6a51490b 00 02dd 01 19f8 0004 f80a 000a 0005 f009 c009 000b
        // 1a 18 6a51490b 00 02de 01 19f8 0005 f80a 000a 0005 f009 c009 000b

        let cmd1 = SetInsulinScheduleCommand(nonce: 0x6a51490b, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a186a51490b0002dd0119f80004f80a000a0005f009c009000b", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ YYYY ZZZZZZZZ YYYY ZZZZZZZZ YYYY ZZZZZZZZ
        // 13 20 00 00 065e 00def8a1 06f9 01059449 0037 01f360e8 0a32 01312d00 0073 00eed54d
        // 13 20 00 00 067c 00b8e008 06f9 01059449 0037 01f360e8 0a32 01312d00 0073 00eed54d

        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: false, programReminderInterval: 0)
        XCTAssertEqual("13200000065e00def8a106f901059449003701f360e80a3201312d00007300eed54d", cmd2.data.hexadecimalString) // PDM
        //checkBasalScheduleExtraCommandDataWithLessPrecision(Data(hexadecimalString: "13200000067c00b8e00806f901059449003701f360e80a3201312d00007300eed54d")!, cmd2.data)
    }

    func testBasalExtraEncoding4() {
        // Encode
        
        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.05, startTime: 0)])
        
        // 16:02:26 - 1a122a845e170003142033c00009f80af80af80a130e40000688009cf29113b001059449028a
        
        let hh       = 0x20       // 16:00, rate = 1.05
        let ssss     = 0x33c0     // 1656s left, 144s into segment
        let xxxxxxxx = 0x009cf291 // 102.85713s until next pulse
        let offset = TimeInterval(minutes: Double((hh + 1) * 30)) - TimeInterval(seconds: Double(ssss / 8)) - TimeInterval(xxxxxxxx % 100000) / 100000
        
        // 1a 18 6a51490b 00 02dd 01 19f8 0004 f80a 000a 0005 f009 c009 000b 13 20 00 0006 5e 00def8a1 06f9 01059449 0037 01f360e8 0a32 01312d00 0073
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp
        // 1a 12 2a845e17 00 0314 20 33c0 0009 f80a f80a f80a

        let cmd1 = SetInsulinScheduleCommand(nonce: 0x2a845e17, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a122a845e170003142033c00009f80af80af80a", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ
        // 13 0e 40 00 0688 009cf291 13b0 01059449
        // 13 0e 00 00 0690 002b291a 13b0 01059449
        
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("130e40000688009cf29113b001059449", cmd2.data.hexadecimalString)
    }
    
    func testBasalExtraEncoding5() {
        // Encode
        
        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.05, startTime: 0)])
        
        // 17:47:27 1a 12 0a229e93 00 02d6 23 17a0 0004 f80a f80a f80a 13 0e 40 00 0519 001a2865 13b0 01059449 0220
        
        let hh       = 0x23       // 17:30, rate = 1.05
        let ssss     = 0x17a0     // 756s left, 1044s into segment
        let xxxxxxxx = 0x001a2865 // 17s until next pulse
        let offset = TimeInterval(minutes: Double((hh + 1) * 30)) - TimeInterval(seconds: Double(ssss / 8)) - TimeInterval(xxxxxxxx % 100000) / 100000
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp
        // 1a 12 0a229e93 00 02d6 23 17a0 0004 f80a f80a f80a
        
        let cmd1 = SetInsulinScheduleCommand(nonce: 0x0a229e93, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a120a229e930002d62317a00004f80af80af80a", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ
        // 13 0e 40 00 0519 001a2865 13b0 01059449
        // 13 0e 40 00 051e 006b7720 13b0 01059449
        
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("130e40000519001a286513b001059449", cmd2.data.hexadecimalString)
    }

    func testBasalExtraEncodingSelfCheck1() {
        // Test encoding not against PDM data, but against an assumption that pulses should happen halfway through
        // the period; i.e. that PPPP will decrement at 90 degree phase of the rate periodicity, with 0 degrees at the top of the hour
        // and that XXXXXXXX is amount of time remaining until next pulse, in hundredths of milliseconds
        
        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.0, startTime: 0)])
        
        let offset = TimeInterval(minutes: 0)
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp
        // 1a 12 0a229e93 00 0262 00 3840 000a f00a f00a f00a
        
        let cmd1 = SetInsulinScheduleCommand(nonce: 0x0a229e93, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a120a229e93000262003840000af00af00af00a", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ
        // 13 0e 40 00 12c0 00895440 12c0 0112a880
        
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("130e400012c00089544012c00112a880", cmd2.data.hexadecimalString)
    }

    func testBasalExtraEncodingSelfCheck2() {
        // Test encoding not against PDM data, but against an assumption that pulses should happen halfway through
        // the period; i.e. that PPPP will decrement at 90 degree phase of the rate periodicity, with 0 degrees at the top of the hour
        // and that XXXXXXXX is amount of time remaining until next pulse, in hundredths of milliseconds

        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.0, startTime: 0)])
        
        let offset = TimeInterval(minutes: 2)
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp
        // 1a 12 0a229e93 00 029d 00 3480 0009 f00a f00a f00a
        
        let cmd1 = SetInsulinScheduleCommand(nonce: 0x0a229e93, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a120a229e9300029d0034800009f00af00af00a", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ
        // 13 0e 40 00 12b9 00e4e1c0 12c0 0112a880

        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("130e400012b900e4e1c012c00112a880", cmd2.data.hexadecimalString)
    }

    func testBasalExtraEncodingSelfCheck3() {
        // Test encoding not against PDM data, but against an assumption that pulses should happen halfway through
        // the period; i.e. that PPPP will decrement at 90 degree phase of the rate periodicity, with 0 degrees at the top of the hour
        // and that XXXXXXXX is amount of time remaining until next pulse, in hundredths of milliseconds
        
        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.0, startTime: 0)])
        
        let offset = TimeInterval(hours: 3) + .minutes(46)
        
        // 1a LL NNNNNNNN 00 CCCC HH SSSS PPPP napp napp napp
        // 1a 12 0a229e93 00 0246 07 1a40 0005 f00a f00a f00a
        
        let cmd1 = SetInsulinScheduleCommand(nonce: 0x0a229e93, basalSchedule: schedule, scheduleOffset: offset)
        XCTAssertEqual("1a120a229e93000246071a400005f00af00af00a", cmd1.data.hexadecimalString)
        
        
        // 13 LL RR MM NNNN XXXXXXXX YYYY ZZZZZZZZ
        // 13 0e 40 00 0fce 002dc6c0 12c0 0112a880
        
        let cmd2 = BasalScheduleExtraCommand(schedule: schedule, scheduleOffset: offset, confidenceReminder: true, programReminderInterval: 0)
        XCTAssertEqual("130e40000fce002dc6c012c00112a880", cmd2.data.hexadecimalString)
    }

    func testSuspendBasalCommand() {
        do {
            // Decode 1f 05 6fede14a 01
            let cmd = try CancelDeliveryCommand(encodedData: Data(hexadecimalString: "1f056fede14a01")!)
            XCTAssertEqual(0x6fede14a, cmd.nonce)
            XCTAssertEqual(.noBeep, cmd.beepType)
            XCTAssertEqual(.basal, cmd.deliveryType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = CancelDeliveryCommand(nonce: 0x6fede14a, deliveryType: .basal, beepType: .noBeep)
        XCTAssertEqual("1f056fede14a01", cmd.data.hexadecimalString)
    }
}

