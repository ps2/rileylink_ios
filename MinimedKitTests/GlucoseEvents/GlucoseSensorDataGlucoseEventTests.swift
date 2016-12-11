//
//  GlucoseSensorDataGlucoseEventTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class GlucoseSensorDataGlucoseEventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecoding() {
        let rawData = Data(hexadecimalString: "35")!
        let subject = GlucoseSensorDataGlucoseEvent(availableData: rawData, relativeTimestamp: DateComponents())!
        
        XCTAssertEqual(subject.sgv, 106)
    }
    
}
