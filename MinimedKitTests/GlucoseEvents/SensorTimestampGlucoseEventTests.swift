//
//  SensorTimestampGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class SensorTimestampGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecoding() {
        let rawData = Data(hexadecimalString: "088d9b5d0c")!
        let subject = SensorTimestampGlucoseEvent(availableData: rawData)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2012, month: 10, day: 29, hour: 13, minute: 27)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
}
