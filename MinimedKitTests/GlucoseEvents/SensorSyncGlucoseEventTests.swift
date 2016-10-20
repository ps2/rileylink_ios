//
//  SensorSyncGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class SensorSyncGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        let rawData = Data(hexadecimalString: "0d4d44330f")!
        let subject = SensorSyncGlucoseEvent(availableData: rawData)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 13, minute: 04)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
}
