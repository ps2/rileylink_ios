//
//  TimeFormatTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class TimeFormatTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testParse2ByteDate() {
    let input = NSData(hexadecimalString: "6e351005112ce9b00a000004f001401903b04b00dd01a4013c")!
    let comps = TimeFormat.parse2ByteDate(input, offset: 1)
    XCTAssertEqual(2016, comps.year)
    XCTAssertEqual(21, comps.day)
    XCTAssertEqual(2, comps.month)
  }

  func testParse5ByteDate() {
    let input = NSData(hexadecimalString: "010018001800440001b8571510")!
    let comps = TimeFormat.parse5ByteDate(input, offset: 8)
    XCTAssertEqual(2016, comps.year)
    XCTAssertEqual(21, comps.day)
    XCTAssertEqual(2, comps.month)
    XCTAssertEqual(23, comps.hour)
    XCTAssertEqual(56, comps.minute)
    XCTAssertEqual(1, comps.second)
  }
  
}
