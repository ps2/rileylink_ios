//
//  SensorCalGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class SensorCalGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecodingMeterBgNow() {
        let rawData = Data(hexadecimalString: "0300")!
        let subject = SensorCalGlucoseEvent(availableData: rawData)!
        
        XCTAssertEqual(subject.waiting, "meter_bg_now")
    }
    
    func testDecodingWaiting() {
        let rawData = Data(hexadecimalString: "0301")!
        let subject = SensorCalGlucoseEvent(availableData: rawData)!
        
        XCTAssertEqual(subject.waiting, "waiting")
    }
    
}
