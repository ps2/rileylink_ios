//
//  PacketTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class PacketTests: XCTestCase {
    
    func testPacketData() {
        // 2016-06-26T20:33:28.412197 ID1:1f01482a PTYPE:PDM SEQ:13 ID2:1f01482a B9:10 BLEN:3 BODY:0e0100802c CRC:88
        
        let msg = Message(address: 0x1f01482a, messageBlocks: [GetStatusCommand()], sequenceNum: 4)
        
        let packet = Packet(address: 0x1f01482a, packetType: .pdm, sequenceNum: 13, data: msg.encoded())
        
        XCTAssertEqual("1f01482aad1f01482a10030e0100802c88", packet.encoded().hexadecimalString)
        
        XCTAssertEqual("1f01482a10030e0100802c", packet.data.hexadecimalString)

    }

    func testPacketDecoding() {
        do {
            let packet = try Packet(encodedData: Data(hexadecimalString:"1f01482aad1f01482a10030e0100802c88")!)
            XCTAssertEqual(0x1f01482a, packet.address)
            XCTAssertEqual(13, packet.sequenceNum)
            XCTAssertEqual(.pdm, packet.packetType)
            XCTAssertEqual("1f01482a10030e0100802c", packet.data.hexadecimalString)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
}

