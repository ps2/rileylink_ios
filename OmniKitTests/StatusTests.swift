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
            let encoded = GetStatusCommand(podInfoType: .normal)
            XCTAssertEqual("0e0100", encoded.data.hexadecimalString)
            
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0100")!)
            XCTAssertEqual(.normal, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
    func testStatusRequestCommandConfiguredAlerts() {
        // 0e 01 01
        do {
            // Encode
            let encoded = GetStatusCommand(podInfoType: .configuredAlerts)
            XCTAssertEqual("0e0101", encoded.data.hexadecimalString)
                
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0101")!)
            XCTAssertEqual(.configuredAlerts, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
    func testStatusRequestCommandFaultEvents() {
        // 0e 01 02
        do {
            // Encode
            let encoded = GetStatusCommand(podInfoType: .faultEvents)
            XCTAssertEqual("0e0102", encoded.data.hexadecimalString)
            
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0102")!)
            XCTAssertEqual(.faultEvents, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
 
    func testStatusRequestCommandFlashVariables() {
        // 0e 01 46
        do {
            // Encode
            let encoded = GetStatusCommand(podInfoType: .flashVariables)
            XCTAssertEqual("0e0146", encoded.data.hexadecimalString)
            
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0146")!)
            XCTAssertEqual(.flashVariables, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
}



