//
//  BasalScheduleTests.swift
//  RileyLink
//
//  Created by Jaim Zuber on 5/2/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class BasalScheduleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func testBasicConversion() {
        let sampleDataString = "1300001000030d000810000c0b00140a00180e002010002615002900000000000000000000000000000000000000000000000000000000000000000000000000"
        
        let rxData = Data(hexadecimalString: sampleDataString)!
        let profile = BasalSchedule(data: rxData)
        
        XCTAssertEqual(profile.entries.count, 9)
        
        let basalSchedule = profile.entries
        
        // Test each element
        XCTAssertEqual(basalSchedule[0].index, 0)
        XCTAssertEqual(basalSchedule[0].minutes, 0)
        XCTAssertEqualWithAccuracy(basalSchedule[0].rate, 0.475, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[1].index, 1)
        XCTAssertEqual(basalSchedule[1].minutes, 90)
        XCTAssertEqualWithAccuracy(basalSchedule[1].rate, 0.400, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[2].index, 2)
        XCTAssertEqual(basalSchedule[2].minutes, 240)
        XCTAssertEqualWithAccuracy(basalSchedule[2].rate, 0.325, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[3].index, 3)
        XCTAssertEqual(basalSchedule[3].minutes, 360)
        XCTAssertEqualWithAccuracy(basalSchedule[3].rate, 0.400, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[4].index, 4)
        XCTAssertEqual(basalSchedule[4].minutes, 600)
        XCTAssertEqualWithAccuracy(basalSchedule[4].rate, 0.275, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[5].index, 5)
        XCTAssertEqual(basalSchedule[5].minutes, 720)
        XCTAssertEqualWithAccuracy(basalSchedule[5].rate, 0.25, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[6].index, 6)
        XCTAssertEqual(basalSchedule[6].minutes, 960)
        XCTAssertEqualWithAccuracy(basalSchedule[6].rate, 0.350, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[7].index, 7)
        XCTAssertEqual(basalSchedule[7].minutes, 1140)
        XCTAssertEqualWithAccuracy(basalSchedule[7].rate, 0.400, accuracy: 0.0001)
        
        XCTAssertEqual(basalSchedule[8].index, 8)
        XCTAssertEqual(basalSchedule[8].minutes, 1230)
        XCTAssertEqualWithAccuracy(basalSchedule[8].rate, 0.525, accuracy: 0.0001)
    }
}
