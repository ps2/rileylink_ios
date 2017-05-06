//
//  GetBatteryCarelinkMessageBodyTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class GetBatteryCarelinkMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidGetBatteryResponse() {
        let message = PumpMessage(rxData: Data(hexadecimalString: "a7350535720300008c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a")!)
        
        if let message = message {
            XCTAssertTrue(message.messageBody is GetBatteryCarelinkMessageBody)
            let body = message.messageBody as! GetBatteryCarelinkMessageBody
            XCTAssertEqual(body.volts, 1.4)

            if case .normal = body.status {
                // OK
            } else {
                XCTFail()
            }
        } else {
            XCTFail("\(String(describing: message)) is nil")
        }
    }
}
