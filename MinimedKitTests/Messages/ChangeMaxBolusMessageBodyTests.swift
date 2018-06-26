//
//  ChangeMaxBolusMessageBodyTests.swift
//  MinimedKitTests
//
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class ChangeMaxBolusMessageBodyTests: XCTestCase {

    func testMaxBolus() {
        let body = ChangeMaxBolusMessageBody(maxBolusUnits: 6.4)!

        XCTAssertEqual(Data(hexadecimalString: "0140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")!, body.txData, body.txData.hexadecimalString)
    }

    func testMaxBolusRounded() {
        let body = ChangeMaxBolusMessageBody(maxBolusUnits: 2.25)!

        XCTAssertEqual(Data(hexadecimalString: "0116000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")!, body.txData, body.txData.hexadecimalString)
    }

    func testMaxBolusOutOfRange() {
        XCTAssertNil(ChangeMaxBolusMessageBody(maxBolusUnits: -1))
        XCTAssertNil(ChangeMaxBolusMessageBody(maxBolusUnits: 26))
    }
    
}
