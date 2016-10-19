//
//  GetGlucosePageMessageBodyTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/19/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class GetGlucosePageMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTxDataEncoding() {
        let messageBody = GetGlucosePageMessageBody(pageNum: 13)
        
        XCTAssertEqual(messageBody.txData.subdata(in: 0..<5).hexadecimalString, "040000000d")
    }
    
}
