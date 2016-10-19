//
//  ReadCurrentGlucosePageMessageBodyTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/19/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class ReadCurrentGlucosePageMessageBodyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testResponseInitializer() {
        var responseData = Data(hexadecimalString: "0000000D6100100020")!
        responseData.append(contentsOf: [UInt8](repeating: 0, count: 65 - responseData.count))
        
        let messageBody = ReadCurrentGlucosePageMessageBody(rxData: responseData)!
        
        XCTAssertEqual(messageBody.pageNum, 3425)
        XCTAssertEqual(messageBody.glucose, 16)
        XCTAssertEqual(messageBody.isig, 32)
    }
    
}
