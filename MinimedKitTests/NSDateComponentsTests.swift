//
//  NSDateComponentsTests.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 6/13/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class NSDateComponentsTests: XCTestCase {
    
    func testInitWith5BytePumpEventData() {
        let input = NSData(hexadecimalString: "010018001800440001b8571510")!
        let comps = NSDateComponents(pumpEventData: input, offset: 8)
        XCTAssertEqual(2016, comps.year)
        XCTAssertEqual(21, comps.day)
        XCTAssertEqual(2, comps.month)
        XCTAssertEqual(23, comps.hour)
        XCTAssertEqual(56, comps.minute)
        XCTAssertEqual(1, comps.second)
    }

    func testInitWith2BytePumpEventData() {
        let input = NSData(hexadecimalString: "6e351005112ce9b00a000004f001401903b04b00dd01a4013c")!
        let comps = NSDateComponents(pumpEventData: input, offset: 1, length: 2)
        XCTAssertEqual(2016, comps.year)
        XCTAssertEqual(21, comps.day)
        XCTAssertEqual(2, comps.month)
    }
    
}
