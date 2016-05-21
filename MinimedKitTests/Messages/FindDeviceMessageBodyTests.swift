//
//  FindDeviceMessageBodyTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class FindDeviceMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidFindDeviceMessage() {
        let message = PumpMessage(rxData: NSData(hexadecimalString: "a235053509cf9999990062")!)
        
        if let message = message {
            XCTAssertTrue(message.messageBody is FindDeviceMessageBody)
        } else {
            XCTFail("\(message) is nil")
        }
    }
    
    func testMidnightSensor() {
        let message = PumpMessage(rxData: NSData(hexadecimalString: "a235053509cf9999990062")!)!
        
        let body = message.messageBody as! FindDeviceMessageBody
        
        XCTAssertEqual(body.sequence, 79)
        XCTAssertEqual(body.deviceAddress.hexadecimalString, "999999")
    }
}
