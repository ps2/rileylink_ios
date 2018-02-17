//
//  MessageTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class MessageTests: XCTestCase {
    
    func testMessageData() {
        // 2016-06-26T20:33:28.412197 ID1:1f01482a PTYPE:PDM SEQ:13 ID2:1f01482a B9:10 BLEN:3 BODY:0e0100802c CRC:88
        
        let msg = Message(address: 0x1f01482a, messageBlocks: [GetStatusCommand()], sequenceNum: 4)
        
        XCTAssertEqual("1f01482a10030e0100802c", msg.encoded().hexadecimalString)
    }
    
    func testMessageDecoding() {
        do {
            //11 POD 1d(10)->Resp Status:
            // Basal running
            // PODState:Normal running
            // Insulin(total):4.85u
            // PODMsg#14
            // Insulin not delivered:0.00u 0
            // Alert:Normal
            // POD Active for 1 days 19 hours 26 minutes
            let msg = try Message(encodedData: Data(hexadecimalString: "1f00ee84300a1d18003f1800004297ff8128")!)
            
            XCTAssertEqual(0x1f00ee84, msg.address)
            XCTAssertEqual(12, msg.sequenceNum)
            
            let messageBlocks = msg.messageBlocks
            
            XCTAssertEqual(1, messageBlocks.count)
            
            let statusResponse = messageBlocks[0] as! StatusResponse
            
            XCTAssertEqual(50, statusResponse.reservoirLevel)
            XCTAssertEqual(TimeInterval(minutes: 4261), statusResponse.timeActive)

            XCTAssertEqual(.basalRunning, statusResponse.deliveryStatus)
            XCTAssertEqual(.aboveFiftyUnits, statusResponse.reservoirStatus)
            XCTAssertEqual(6.3, statusResponse.insulin, accuracy: 0.01)
            XCTAssertEqual(0, statusResponse.insulinNotDelivered)
            XCTAssertEqual(3, statusResponse.podMessageCounter)
            XCTAssertEqual(.normal, statusResponse.ageStatus)


            XCTAssertEqual("1f00ee84300a1d18003f1800004297ff8128", msg.encoded().hexadecimalString)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testAssignAddressCommand() {
        
        let msg = AssignAddressCommand(address: 0x1f01482a)
        
        XCTAssertEqual("07041f01482a", msg.data.hexadecimalString)
    }
    

}

