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
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSyncTypeNew() {
        let rawData = Data(hexadecimalString: "0d4d44330f")!
        let subject = SensorSyncGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 13, minute: 04)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.syncType, "new")
    }
    
    func testSyncTypeOld() {
        let rawData = Data(hexadecimalString: "0d4d44530f")!
        let subject = SensorSyncGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 13, minute: 04)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.syncType, "old")
    }
    
    func testSyncTypeFind() {
        let rawData = Data(hexadecimalString: "0d4d44730f")!
        let subject = SensorSyncGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 13, minute: 04)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.syncType, "find")
    }
    
}
