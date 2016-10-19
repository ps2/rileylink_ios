//
//  DateTimeChangeGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class DateTimeChangeGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecoding() {
        let pumpModel = PumpModel.Model551
        let rawData = Data(hexadecimalString: "0c0ad23e0e")!
        let subject = DateTimeChangeGlucoseEvent(availableData: rawData, pumpModel: pumpModel)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 3, day: 30, hour: 10, minute: 18)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
}
