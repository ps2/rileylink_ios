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
}

