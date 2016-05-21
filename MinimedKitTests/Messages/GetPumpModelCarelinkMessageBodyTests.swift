//
//  GetPumpModelCarelinkMessageBodyTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class GetPumpModelCarelinkMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidGetModelResponse() {
        let message = PumpMessage(rxData: NSData(hexadecimalString: "a73505358d09033532330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f")!)
        
        if let message = message {
            XCTAssertTrue(message.messageBody is GetPumpModelCarelinkMessageBody)
            let body = message.messageBody as! GetPumpModelCarelinkMessageBody
            XCTAssertEqual(body.model, "523")
        } else {
            XCTFail("\(message) is nil")
        }
    }
    
}
