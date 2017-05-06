//
//  DeviceLinkMessageBodyTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class DeviceLinkMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidDeviceLinkMessage() {
        let message = PumpMessage(rxData: Data(hexadecimalString: "a23505350a93ce8aa000ba")!)
        
        if let message = message {
            XCTAssertTrue(message.messageBody is DeviceLinkMessageBody)
        } else {
            XCTFail("\(String(describing: message)) is nil")
        }
    }
    
    func testMidnightSensor() {
        let message = PumpMessage(rxData: Data(hexadecimalString: "a23505350a93ce8aa000ba")!)!
        
        let body = message.messageBody as! DeviceLinkMessageBody
        
        XCTAssertEqual(body.sequence, 19)
        XCTAssertEqual(body.deviceAddress.hexadecimalString, "ce8aa0")
    }
}
