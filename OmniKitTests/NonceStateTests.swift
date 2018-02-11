//
//  NonceStateTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class NonceStateTests: XCTestCase {
    
    func testInitialNonceValue() {
        let nonceState = NonceState(lot: 42560, tid: 661771)
        XCTAssertEqual(nonceState.nextNonce(), 0x8c61ee59)
        XCTAssertEqual(nonceState.nextNonce(), 0xc0256620)
        XCTAssertEqual(nonceState.nextNonce(), 0x15022c8a)
        XCTAssertEqual(nonceState.nextNonce(), 0xacf076ca)
    }
}

