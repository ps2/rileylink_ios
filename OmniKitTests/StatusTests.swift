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

    func testStatusResponse46UnitsLeft() {
        /// 1d19050ec82c08376f9801dc
        do {
            // Decode
            let decoded = try StatusResponse(encodedData: Data(hexadecimalString: "1d19050ec82c08376f9801dc")!)
            XCTAssertEqual(TimeInterval(minutes: 3547), decoded.timeActive)
            XCTAssertEqual(.normal, decoded.deliveryStatus)
            XCTAssertEqual(.belowFiftyUnits, decoded.podProgressStatus)
            XCTAssertEqual(129.45, decoded.insulin, accuracy: 0.01)
            XCTAssertEqual(46.00, decoded.reservoirLevel)
            XCTAssertEqual(2.2, decoded.insulinNotDelivered)
            XCTAssertEqual(9, decoded.podMessageCounter)
            //XCTAssert(,decoded.alarms)
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
 
    func testStatusRequestCommandResetStatus() {
        // 0e 01 46
        do {
            // Encode
            let encoded = GetStatusCommand(podInfoType: .resetStatus)
            XCTAssertEqual("0e0146", encoded.data.hexadecimalString)
            
            // Decode
            let decoded = try GetStatusCommand(encodedData: Data(hexadecimalString: "0e0146")!)
            XCTAssertEqual(.resetStatus, decoded.podInfoType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
}



