//
//  SensorStatusGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class SensorStatusGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testDecodingStatusTypeOff() {
        let rawData = Data(hexadecimalString: "0b0baf0a0e")!
        let subject = SensorStatusGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 2, day: 10, hour: 11, minute: 47)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.dictionaryRepresentation["statusType"] as! String, "off")
    }
    
    func testDecodingStatusTypeOn() {
        let rawData = Data(hexadecimalString: "0b0baf2a0e")!
        let subject = SensorStatusGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 2, day: 10, hour: 11, minute: 47)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.dictionaryRepresentation["statusType"] as! String, "on")
    }
    
    func testDecodingStatusTypeLost() {
        let rawData = Data(hexadecimalString: "0b0baf4a0e")!
        let subject = SensorStatusGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 2, day: 10, hour: 11, minute: 47)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.dictionaryRepresentation["statusType"] as! String, "lost")
    }
}
