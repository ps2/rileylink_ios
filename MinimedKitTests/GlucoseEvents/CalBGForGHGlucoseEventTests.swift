//
//  CalBGForGHGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class CalBGForGHGlucoseEventTests: XCTestCase {
    
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
        let rawData = Data(hexadecimalString: "0e4f5b138fa0")!
        let subject = CalBGForGHGlucoseEvent(availableData: rawData, pumpModel: pumpModel)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2015, month: 5, day: 19, hour: 15, minute: 27)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
        XCTAssertEqual(subject.amount, 160)
    }
    
}
