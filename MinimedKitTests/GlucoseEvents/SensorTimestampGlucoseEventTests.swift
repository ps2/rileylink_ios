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
    
    func testDecodingPageEnd() {
        let rawData = Data(hexadecimalString: "0814B62810")!
        let subject = SensorTimestampGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        XCTAssertEqual(subject.dictionaryRepresentation["timestampType"] as! String, "page_end")
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2016, month: 02, day: 08, hour: 20, minute: 54)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
    
    func testTimestampTypeLastRf() {
        let rawData = Data(hexadecimalString: "088d9b5d0c")!
        let subject = SensorTimestampGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        XCTAssertEqual(subject.dictionaryRepresentation["timestampType"] as! String, "gap")
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2012, month: 10, day: 29, hour: 13, minute: 27)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
    func testTimestampTypeGap() {
        let rawData = Data(hexadecimalString: "088d9b1d0c")!
        let subject = SensorTimestampGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        XCTAssertEqual(subject.dictionaryRepresentation["timestampType"] as! String, "last_rf")
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2012, month: 10, day: 29, hour: 13, minute: 27)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
}
