//
//  BolusTests.swift
//  OmniKitTests
//
//  Created by Eelke Jager on 04/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import XCTest
@testable import OmniKit

class BolusTests: XCTestCase {
        func testSetBolusCommand() {
        //    2017-09-11T11:07:57.476872 ID1:1f08ced2 PTYPE:PDM SEQ:18 ID2:1f08ced2 B9:18 BLEN:31 MTYPE:1a0e BODY:bed2e16b02010a0101a000340034170d000208000186a0 CRC:fd
        //    2017-09-11T11:07:57.552574 ID1:1f08ced2 PTYPE:ACK SEQ:19 ID2:1f08ced2 CRC:b8
        //    2017-09-11T11:07:57.734557 ID1:1f08ced2 PTYPE:CON SEQ:20 CON:00000000000003c0 CRC:a9
        
        do {
            // Decode
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0ebed2e16b02010a0101a000340034")!)
            XCTAssertEqual(0xbed2e16b, cmd.nonce)
            
            if case SetInsulinScheduleCommand.DeliverySchedule.bolus(let units, let multiplier) = cmd.deliverySchedule {
                XCTAssertEqual(2.6, units)
                XCTAssertEqual(0x8, multiplier)
            } else {
                XCTFail("Expected ScheduleEntry.bolus type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let scheduleEntry = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: 2.6, multiplier: 0x8)
        let cmd = SetInsulinScheduleCommand(nonce: 0xbed2e16b, deliverySchedule: scheduleEntry)
        XCTAssertEqual("1a0ebed2e16b02010a0101a000340034", cmd.data.hexadecimalString)
    }

    func testBolusExtraCommand() {
        // 30U bolus
        // 170d 7c 1770 00030d40 000000000000
        
        do {
            // Decode
            let cmd = try BolusExtraCommand(encodedData: Data(hexadecimalString: "170d7c177000030d40000000000000")!)
            XCTAssertEqual(30.0, cmd.units)
            XCTAssertEqual(0x7c, cmd.byte2)
            XCTAssertEqual(Data(hexadecimalString: "00030d40"), cmd.unknownSection)
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = BolusExtraCommand(units: 2.6, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        XCTAssertEqual("170d000208000186a0000000000000", cmd.data.hexadecimalString)
    }
    
    func testCancelBolusCommand() {
        do {
            // Decode 1f 05 4d91f8ff 64
            let cmd = try CancelDeliveryCommand(encodedData: Data(hexadecimalString: "1f054d91f8ff64")!)
            XCTAssertEqual(0x4d91f8ff, cmd.nonce)
            XCTAssertEqual(.beeeeeep, cmd.beepType)
            XCTAssertEqual(.bolus, cmd.deliveryType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = CancelDeliveryCommand(nonce: 0x4d91f8ff, deliveryType: .bolus, beepType: .beeeeeep)
        XCTAssertEqual("1f054d91f8ff64", cmd.data.hexadecimalString)
    }
}
