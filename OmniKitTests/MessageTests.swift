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
    
    func testAssemblingMultiPacketMessage() {
        do {
            let packet1 = try Packet(encodedData: Data(hexadecimalString: "ffffffffe4ffffffff041d011b13881008340a5002070002070002030000a62b0004479420")!)
            XCTAssertEqual(packet1.data.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b00044794")
            XCTAssertEqual(packet1.packetType, .pod)

            XCTAssertThrowsError(try Message(encodedData: packet1.data)) { error in
                XCTAssertEqual(String(describing: error), "notEnoughData")
            }
            
            let packet2 = try Packet(encodedData: Data(hexadecimalString: "ffffffff861f00ee878352ff")!)
            XCTAssertEqual(packet2.address, 0xffffffff)
            XCTAssertEqual(packet2.data.hexadecimalString, "1f00ee878352")
            XCTAssertEqual(packet2.packetType, .con)
            
            let messageBody = packet1.data + packet2.data
            XCTAssertEqual(messageBody.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")

            let message = try Message(encodedData: messageBody)
            XCTAssertEqual(message.messageBlocks.count, 1)

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingConfigResponse() {
        do {
            let config = try ConfigResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a64000097c279c1f08ced2")!)
            XCTAssertEqual(23, config.length)
            XCTAssertEqual(0x1f08ced2, config.address)
            XCTAssertEqual(42560, config.lot)
            XCTAssertEqual(621607, config.tid)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingLongConfigResponse() {
        do {
            let message = try Message(encodedData: Data(hexadecimalString: "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")!)
            let config = message.messageBlocks[0] as! ConfigResponse
            XCTAssertEqual(29, config.length)
            XCTAssertEqual(0x1f00ee87, config.address)
            XCTAssertEqual(42539, config.lot)
            XCTAssertEqual(280468, config.tid)
            XCTAssertEqual("2.7.0", String(describing: config.piVersion))
            XCTAssertEqual("2.7.0", String(describing: config.pmVersion))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testAssignAddressCommand() {
        do {
            // Encode
            let encoded = AssignAddressCommand(address: 0x1f01482a)
            XCTAssertEqual("07041f01482a", encoded.data.hexadecimalString)

            // Decode
            let decoded = try AssignAddressCommand(encodedData: Data(hexadecimalString: "07041f01482a")!)
            XCTAssertEqual(0x1f01482a, decoded.address)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testSetPodTimeCommand() {
        do {
            var components = DateComponents()
            components.day = 6
            components.month = 12
            components.year = 2016
            components.hour = 13
            components.minute = 47

            // Decode
            let decoded = try SetPodTimeCommand(encodedData: Data(hexadecimalString: "03131f0218c31404060c100d2f0000a4be0004e4a1")!)
            XCTAssertEqual(0x1f0218c3, decoded.address)
            XCTAssertEqual(components, decoded.dateComponents)
            XCTAssertEqual(0x0000a4be, decoded.lot)
            XCTAssertEqual(0x0004e4a1, decoded.tid)

            // Encode
            let encoded = SetPodTimeCommand(address: 0x1f0218c3, dateComponents: components, lot: 0x0000a4be, tid: 0x0004e4a1)
            XCTAssertEqual("03131f0218c31404060c100d2f0000a4be0004e4a1", encoded.data.hexadecimalString)            

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
}

