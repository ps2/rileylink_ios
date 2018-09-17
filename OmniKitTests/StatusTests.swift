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
            let decoded = try StatusResponseConfiguredAlerts(encodedData: Data(hexadecimalString: "021301000000000000000000000000000000000000")!)
            XCTAssertEqual(.statusError, decoded.blockType)
            XCTAssertEqual(.configuredAlerts, decoded.statusType)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testStatusEndSuspendConfiguredAlerts() {
        // 02 13 01 0000 0000 0000 0000 0000 0000 0bd7 0c40 0000 828c
        // 02 13 01 0000 0102 0304 0506 0708 090a 0bd7 0c40 0000 828c
        // AlarmTyoe     1    2    3    4    5    6    7    8
  // alertActivation nr  0    1    2    3    4    5    6    7
        do {
            // Decode
            let decoded = try StatusResponseConfiguredAlerts(encodedData: Data(hexadecimalString: "0213010000000000000000000000000bd70c400000828c")!)
            XCTAssertEqual(.statusError, decoded.blockType)
            XCTAssertEqual(.configuredAlerts, decoded.statusType)
            XCTAssertEqual(.beepBeepBeep, decoded.alertsActivations[5].beepType)
            XCTAssertEqual(11, decoded.alertsActivations[5].timeFromPodStart) // in minutes
            XCTAssertEqual(10.75, decoded.alertsActivations[5].pulsesLeft) //, accuracy: 1)
            XCTAssertEqual(.beeeeeep, decoded.alertsActivations[6].beepType)
            XCTAssertEqual(12, decoded.alertsActivations[6].timeFromPodStart) // in minutes
            XCTAssertEqual(3.2, decoded.alertsActivations[6].pulsesLeft) //, accuracy: 1)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
        
    func testStatusErrorNoFaultAlerts() {
    // 02 16 02 08 01 0000 0a 0038 00 0000 03ff 0087 00 00 00 95 ff 0000 //recorded an extra 81
    
        do {
            // Decode
            let decoded = try StatusResponseFaultEvent(encodedData: Data(hexadecimalString: "021602080100000a003800000003ff008700000095ff0000")!)
            XCTAssertEqual(.faultEvents, decoded.statusType)
            XCTAssertEqual(22, decoded.length)
            XCTAssertEqual(.aboveFiftyUnits, decoded.reservoirStatus)
            XCTAssertEqual(.basal, decoded.deliveryInProgressType)
            XCTAssertEqual(0000, decoded.insulinNotDelivered)
            XCTAssertEqual(0x0a, decoded.podMessageCounter)
            XCTAssertEqual(00, decoded.originalLoggedFaultEvent)
            XCTAssertEqual(0000, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(51.15, decoded.insulinRemaining, accuracy: 0.05)
            XCTAssertEqual(135*60, decoded.timeActive, accuracy: 0) // timeActive converts minutes to seconds
            XCTAssertEqual(00, decoded.secondaryLoggedFaultEvent)
            XCTAssertEqual(false, decoded.logEventError)
            XCTAssertEqual(.insulinStateCorruptionDuringErrorLogging, decoded.infoLoggedFaultEvent)
            XCTAssertEqual(.initialized, decoded.reservoirStatusAtFirstLoggedFaultEvent)
            XCTAssertEqual(9, decoded.recieverLowGain)
            XCTAssertEqual(5, decoded.radioRSSI)
            XCTAssertEqual(.inactive, decoded.reservoirStatusAtFirstLoggedFaultEventCheck)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
    }
    
    func testStatusErrorFaultAlert() {
        // 02 16 02 0d 00 0000 06 0034 5c 0001 03ff 0001 00 00 05 a1 05 0186
        do {
            // Decode
            let decoded = try StatusResponseFaultEvent(encodedData: Data(hexadecimalString: "0216020d0000000600345c000103ff0001000005a1050186")!)
            XCTAssertEqual(.faultEvents, decoded.statusType)
            XCTAssertEqual(22, decoded.length)
            XCTAssertEqual(.errorEventLoggedShuttingDown, decoded.reservoirStatus)
            XCTAssertEqual(.none, decoded.deliveryInProgressType)
            XCTAssertEqual(0000, decoded.insulinNotDelivered)
            XCTAssertEqual(6, decoded.podMessageCounter)
            XCTAssertEqual(92, decoded.originalLoggedFaultEvent)
            XCTAssertEqual(0001*60, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(51.15, decoded.insulinRemaining, accuracy: 0.05)
            XCTAssertEqual(0001*60, decoded.timeActive, accuracy: 0) // timeActive converts minutes to seconds
            XCTAssertEqual(00, decoded.secondaryLoggedFaultEvent)
            XCTAssertEqual(false, decoded.logEventError)
            XCTAssertEqual(.insulinStateCorruptionDuringErrorLogging, decoded.infoLoggedFaultEvent)
            XCTAssertEqual(.readyForInjection, decoded.reservoirStatusAtFirstLoggedFaultEvent)
            XCTAssertEqual(10, decoded.recieverLowGain)
            XCTAssertEqual(1, decoded.radioRSSI)
            XCTAssertEqual(.readyForInjection, decoded.reservoirStatusAtFirstLoggedFaultEventCheck)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testStatusErrorDeliveryErrorDuringPriming() {
        //0216 BODY:020f0000000900345c000103ff0001000005ae05602903
        do {
            // Decode
            let decoded = try StatusResponseFaultEvent(encodedData: Data(hexadecimalString: "0216020f0000000900345c000103ff0001000005ae05602903")!)
            XCTAssertEqual(.faultEvents, decoded.statusType)
            XCTAssertEqual(22, decoded.length)
            XCTAssertEqual(.inactive, decoded.reservoirStatus)
            XCTAssertEqual(.none, decoded.deliveryInProgressType)
            XCTAssertEqual(0000, decoded.insulinNotDelivered)
            XCTAssertEqual(9, decoded.podMessageCounter)
            XCTAssertEqual(92, decoded.originalLoggedFaultEvent)
            XCTAssertEqual(0001*60, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(51.15, decoded.insulinRemaining, accuracy: 0.05)
            XCTAssertEqual(0001*60, decoded.timeActive, accuracy: 0) // timeActive converts minutes to seconds
            XCTAssertEqual(00, decoded.secondaryLoggedFaultEvent)
            XCTAssertEqual(false, decoded.logEventError)
            XCTAssertEqual(.insulinStateCorruptionDuringErrorLogging, decoded.infoLoggedFaultEvent)
            XCTAssertEqual(.readyForInjection, decoded.reservoirStatusAtFirstLoggedFaultEvent)
            XCTAssertEqual(10, decoded.recieverLowGain)
            XCTAssertEqual(14, decoded.radioRSSI)
            XCTAssertEqual(.readyForInjection, decoded.reservoirStatusAtFirstLoggedFaultEventCheck)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    func testStatusErrorDuringPriming() {
        // Needle cap accidentally removed before priming started leaking and gave error:
        // 0216020d0000000600008f000003ff0000000003a20386a002
        do {
            // Decode
            let decoded = try StatusResponseFaultEvent(encodedData: Data(hexadecimalString: "0216020d0000000600008f000003ff0000000003a20386a002")!)
            XCTAssertEqual(.faultEvents, decoded.statusType)
            XCTAssertEqual(22, decoded.length)
            XCTAssertEqual(.errorEventLoggedShuttingDown, decoded.reservoirStatus)
            XCTAssertEqual(.none, decoded.deliveryInProgressType)
            XCTAssertEqual(0000, decoded.insulinNotDelivered)
            XCTAssertEqual(6, decoded.podMessageCounter)
            XCTAssertEqual(143, decoded.originalLoggedFaultEvent)
            XCTAssertEqual(0000*60, decoded.faultEventTimeSinceActivation)
            XCTAssertEqual(51.15, decoded.insulinRemaining, accuracy: 0.05)
            XCTAssertEqual(0000*60, decoded.timeActive, accuracy: 0) // timeActive converts minutes to seconds
            XCTAssertEqual(00, decoded.secondaryLoggedFaultEvent)
            XCTAssertEqual(false, decoded.logEventError)
            XCTAssertEqual(.insulinStateCorruptionDuringErrorLogging, decoded.infoLoggedFaultEvent)
            XCTAssertEqual(.pairingSuccess, decoded.reservoirStatusAtFirstLoggedFaultEvent)
            XCTAssertEqual(10, decoded.recieverLowGain)
            XCTAssertEqual(2, decoded.radioRSSI)
            XCTAssertEqual(.pairingSuccess, decoded.reservoirStatusAtFirstLoggedFaultEventCheck)
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
