//
//  StatusTests.swift
//  OmniKitTests
//
//  Created by Eelke Jager on 08/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//
import Foundation

import XCTest
@testable import OmniKit

class StatusTests: XCTestCase {
    func testStatusRequestCommand() {
        // 0e 01 00
        do {
            // Encode
            let encoded = GetStatusCommand(requestType: .normal)
            XCTAssertEqual("0e0100", encoded.data.hexadecimalString)
            
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0100")!)
            XCTAssertEqual(.normal, decoded.requestType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
}
