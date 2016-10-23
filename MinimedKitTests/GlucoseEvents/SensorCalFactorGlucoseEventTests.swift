//
//  SensorCalFactorGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class SensorCalFactorGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecoding() {
        let rawData = Data(hexadecimalString: "0f4f67130f128c")!
        let subject = SensorCalFactorGlucoseEvent(availableData: rawData)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 15, minute: 39)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.factor, 4.748)
    }
    
}
