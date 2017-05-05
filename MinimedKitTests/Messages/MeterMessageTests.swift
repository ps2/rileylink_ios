//
//  MeterMessageTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class MeterMessageTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidMeterMessage() {
        let message = MeterMessage(rxData: Data(hexadecimalString: "a5c527ad018e77")!)
        
        if let message = message {
            XCTAssertEqual(message.glucose, 257)
            XCTAssertEqual(message.ackFlag, false)
        } else {
            XCTFail("\(String(describing:message)) is nil")
        }
    }
    
}
