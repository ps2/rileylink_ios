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
        
    func testDecode4b6b() {
        let input = Data(hexadecimalString: "ab2959595965574ab2d31c565748ea54e55a54b5558cd8cd55557194b56357156535ac5659956a55c55555556355555568bc5657255554e55a54b5555555b100")!
        
        let result = decode4b6b(input)
        
        if let result = result {
            let expectedOutput = Data(hexadecimalString: "a259705504a24117043a0e080b003d3d00015b030105d817790a0f00000300008b1702000e080b000071")
            XCTAssertTrue(result == expectedOutput)
        } else {
            XCTFail("\(String(describing: result)) is nil")
        }
    }
    
    func testDecode4b6bWithBadData() {
        let input = Data(hexadecimalString: "0102030405")!
        
        let result = decode4b6b(input)
        XCTAssertTrue(result == nil)
    }
    
    
    func testEncode4b6b() {
        let input = Data(hexadecimalString: "a259705504a24117043a0e080b003d3d00015b030105d817790a0f00000300008b1702000e080b000071")!
        
        let result = encode4b6b(input)
        
        let expectedOutput = Data(hexadecimalString: "ab2959595965574ab2d31c565748ea54e55a54b5558cd8cd55557194b56357156535ac5659956a55c55555556355555568bc5657255554e55a54b5555555b1")
        XCTAssertTrue(result == expectedOutput)
    }
    
    
}
