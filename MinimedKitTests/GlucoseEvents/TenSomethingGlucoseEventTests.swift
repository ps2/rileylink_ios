//
//  TenSomethingGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class TenSomethingGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecoding() {
        let rawData = Data(hexadecimalString: "100bb40a0e")!
        let subject = TenSomethingGlucoseEvent(availableData: rawData)!
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 2, day: 10, hour: 11, minute: 52)
        XCTAssertEqual(subject.timestamp, expectedTimestamp)
    }
    
}
