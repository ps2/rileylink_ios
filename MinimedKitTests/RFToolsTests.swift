//
//  RFToolsTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class RFToolsTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testDecode4b6b() {
    let input = NSData(hexadecimalString: "ab2959595965574ab2d31c565748ea54e55a54b5558cd8cd55557194b56357156535ac5659956a55c55555556355555568bc5657255554e55a54b5555555b100")!
    
    let result = decode4b6b(input)
    
    if let result = result {
      let expectedOutput = NSData(hexadecimalString: "a259705504a24117043a0e080b003d3d00015b030105d817790a0f00000300008b1702000e080b000071")
      XCTAssertTrue(result == expectedOutput)
    } else {
      XCTFail("\(result) is nil")
    }
  }

  func testDecode4b6bWithBadData() {
    let input = NSData(hexadecimalString: "0102030405")!
    
    let result = decode4b6b(input)
    XCTAssertTrue(result == nil)    
  }

  
  func testEncode4b6b() {
    let input = NSData(hexadecimalString: "a259705504a24117043a0e080b003d3d00015b030105d817790a0f00000300008b1702000e080b000071")!
    
    let result = encode4b6b(input)
    
    NSLog("output = %@", result)
    let expectedOutput = NSData(hexadecimalString: "ab2959595965574ab2d31c565748ea54e55a54b5558cd8cd55557194b56357156535ac5659956a55c55555556355555568bc5657255554e55a54b5555555b1")
    XCTAssertTrue(result == expectedOutput)
  }


}