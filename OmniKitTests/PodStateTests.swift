//
//  PodStateTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class PodStateTests: XCTestCase {
    
    func testNonceValues() {
        
        var podState = PodState(address: 0x1f000000, activatedAt: Date(), timeZone: .currentFixed, piVersion: "1.1.0", pmVersion: "1.1.0", lot: 42560, tid: 661771)
        
        XCTAssertEqual(podState.currentNonce, 0x8c61ee59)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0xc0256620)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0x15022c8a)
        podState.advanceToNextNonce()
        XCTAssertEqual(podState.currentNonce, 0xacf076ca)
    }
    
    func testNonceSync() {
        do {
            let config = try ConfigResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a62b0002249da11f00ee860318")!)
            var podState = PodState(address: 0x1f00ee86, activatedAt: Date(), timeZone: .currentFixed, piVersion: "1.1.0", pmVersion: "1.1.0", lot: config.lot, tid: config.tid)

            XCTAssertEqual(42539, config.lot)
            XCTAssertEqual(140445,  config.tid)
            
            XCTAssertEqual(0x8fd39264,  podState.currentNonce)

            // ID1:1f00ee86 PTYPE:PDM SEQ:26 ID2:1f00ee86 B9:24 BLEN:6 BODY:1c042e07c7c703c1 CRC:f4
            let sentPacket = try Packet(encodedData: Data(hexadecimalString: "1f00ee86ba1f00ee8624061c042e07c7c703c1f4")!)
            let sentMessage = try Message(encodedData: sentPacket.data)
            let sentCommand = sentMessage.messageBlocks[0] as! DeactivatePodCommand
            
            let errorResponse = try ErrorResponse(encodedData: Data(hexadecimalString: "06031492c482f5")!)

            XCTAssertEqual(9, sentMessage.sequenceNum)

            podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: sentCommand.nonce, messageSequenceNum: sentMessage.sequenceNum)
            
            XCTAssertEqual(0x40ccdacb,  podState.currentNonce)


        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testNonceSync2() {
        do {
            let config = try ConfigResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a48d000298bfa01f07b1ee000b")!)
            var podState = PodState(address: 0x1f07b1ee, activatedAt: Date(), timeZone: .currentFixed, piVersion: "1.1.0", pmVersion: "1.1.0", lot: config.lot, tid: config.tid)
            
            XCTAssertEqual(42125, config.lot)
            XCTAssertEqual(170175,  config.tid)

            XCTAssertEqual(0x8d27868e,  podState.currentNonce)

            
            // ID1:1f07b1ee PTYPE:PDM SEQ:03 ID2:1f07b1ee B9:04 BLEN:7 BODY:1f05851072aa620017 CRC:0a
            let sentPacket = try Packet(encodedData: Data(hexadecimalString: "1f07b1eea31f07b1ee04071f05851072aa6200170a")!)
            let sentMessage = try Message(encodedData: sentPacket.data)
            let sentCommand = sentMessage.messageBlocks[0] as! CancelBolusCommand
            
            let errorResponse = try ErrorResponse(encodedData: Data(hexadecimalString: "0603142ffa83cd")!)
            
            XCTAssertEqual(1, sentMessage.sequenceNum)

            podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: sentCommand.nonce, messageSequenceNum: sentMessage.sequenceNum)
            
            XCTAssertEqual(0xf1488fc3, podState.currentNonce)

            
//            2016-10-10T11:23:05.433141 ID1:1f07b1ee PTYPE:PDM SEQ:03 ID2:1f07b1ee B9:04 BLEN:7 BODY:1f05851072aa620017 CRC:0a
//            2016-10-10T11:23:05.793768 ID1:1f07b1ee PTYPE:POD SEQ:04 ID2:1f07b1ee B9:08 BLEN:5 BODY:0603142ffa83cd CRC:35
//            2016-10-10T11:23:06.182224 ID1:1f07b1ee PTYPE:PDM SEQ:06 ID2:1f07b1ee B9:04 BLEN:7 BODY:1f05f1488fc3620229 CRC:7b
            
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

}

