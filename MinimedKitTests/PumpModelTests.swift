//
//  PumpModelTests.swift
//  RileyLink
//
//  Created by Jaim Zuber on 2/24/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class PumpModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func test523AppendsSquareWaveToHistory() {
        XCTAssertTrue(PumpModel.Model523.appendsSquareWaveToHistoryOnStartOfDelivery)
    }
    
    func test522DoesntAppendSquareWaveToHistory() {
        XCTAssertFalse(PumpModel.Model522.appendsSquareWaveToHistoryOnStartOfDelivery)
    }
}
