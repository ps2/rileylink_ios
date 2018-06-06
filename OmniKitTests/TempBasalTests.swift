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
                XCTAssertEqual(2, entry.totalPulses())
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }

        // Encode
        let table = BasalDeliveryTable(schedule: BasalSchedule(entries: [BasalScheduleEntry(rate: 0.2, duration: .hours(0.5))]))
        let deliverySchedule = SetInsulinScheduleCommand.DeliverySchedule.tempBasal(secondsRemaining: 1800, firstSegmentPulses: 2, table: table)
        let cmd = SetInsulinScheduleCommand(nonce: 0xea2d0a3b, deliverySchedule: deliverySchedule)
        XCTAssertEqual("1a0eea2d0a3b01007d01384000020002", cmd.data.hexadecimalString)
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
                XCTAssertEqual(60, entry.totalPulses())
            } else {
                XCTFail("Expected ScheduleEntry.tempBasal type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let table = BasalDeliveryTable(schedule: BasalSchedule(entries: [BasalScheduleEntry(rate: 2.0, duration: .hours(1.5))]))
        let deliverySchedule = SetInsulinScheduleCommand.DeliverySchedule.tempBasal(secondsRemaining: 1800, firstSegmentPulses: 0x14, table: table)
        let cmd = SetInsulinScheduleCommand(nonce: 0x87e8d03a, deliverySchedule: deliverySchedule)
        XCTAssertEqual("1a0e87e8d03a0100cb03384000142014", cmd.data.hexadecimalString)
    }

}
