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
    func testStatusErrorConfiguredAlerts() {
        // 02 13 01 0000 0000 0000 0000 0000 0000 0000 0000 0000
        do {
            // Decode
            let decoded = try StatusError(encodedData: Data(hexadecimalString: "021301000000000000000000000000000000000000")!)
            XCTAssertEqual(.configuredAlerts, decoded.requestedType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
 
    }
    func testStatusErrorFaultAlerts() {
    // 02 16 02 08 01 0000 0a 0038 00 0000 03ff 0087 00 00 00 95 ff00   //recorded an extra 0081
        do {
            // Decode
            let decoded = try StatusError(encodedData: Data(hexadecimalString: "021602080100000a003800000003ff008700000095ff000081")!)
            XCTAssertEqual(.faultEvents, decoded.requestedType)
            XCTAssertEqual(22, decoded.length)
            XCTAssertEqual(.runningNormal, decoded.progressType)
            XCTAssertEqual(.runningNormal, decoded.progressType)
            XCTAssertEqual(.basal, decoded.deliveryInProgressType)
            XCTAssertEqual(0000, decoded.insulinNotDelivered)
            XCTAssertEqual(0x0a, decoded.podMessageCounter)
            XCTAssertEqual(00, decoded.origionalLoggedFaultEvent)
            XCTAssertEqual(0000, decoded.faultEventTimeSinceActivation)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
        
        
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
