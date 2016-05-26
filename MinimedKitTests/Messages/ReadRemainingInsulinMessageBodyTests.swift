//
//  ReadRemainingInsulinMessageBodyTests.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 5/25/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class ReadRemainingInsulinMessageBodyTests: XCTestCase {
    
    func testReservoir723() {
        let message = PumpMessage(rxData: NSData(hexadecimalString: "a7594040730400000ca3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000da")!)

        let body = message?.messageBody as! ReadRemainingInsulinMessageBody

        XCTAssertEqual(80.875, body.getUnitsRemainingForStrokes(PumpModel.Model723.strokesPerUnit))
    }
    
}
