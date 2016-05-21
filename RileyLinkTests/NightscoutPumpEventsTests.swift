//
//  NightscoutPumpEventsTests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit
@testable import NightscoutUploadKit

class NightscoutPumpEventsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBgCheckFromMeter() {
        let events: [PumpEvent] = [
            BGReceivedPumpEvent(availableData: NSData(hexadecimalString: "3f2122938d7510c527ad")!,
                pumpModel: PumpModel.Model523)!
        ]
        let treatments = NightscoutPumpEvents.translate(events, eventSource: "testing")
        XCTAssertEqual(1, treatments.count)
        let bgCheck = treatments[0] as! BGCheckNightscoutTreatment
        XCTAssertEqual(bgCheck.glucose, 268)
        XCTAssertEqual(bgCheck.glucoseType, NightscoutTreatment.GlucoseType.Meter)
        XCTAssertEqual(bgCheck.enteredBy, "testing")
        XCTAssertEqual(bgCheck.units, NightscoutTreatment.Units.MGDL)
    }
    
    func testStandaloneBolus() {
        let events: [PumpEvent] = [
            BolusNormalPumpEvent(availableData: NSData(hexadecimalString: "010080008000240009a24a1510")!,
                pumpModel: PumpModel.Model551)!
        ]
        let treatments = NightscoutPumpEvents.translate(events, eventSource: "testing")
        XCTAssertEqual(1, treatments.count)
        let bolus = treatments[0] as! BolusNightscoutTreatment
        XCTAssertEqual(bolus.amount, 3.2)
        XCTAssertEqual(bolus.bolusType, BolusNightscoutTreatment.BolusType.Normal)
        XCTAssertEqual(bolus.duration, 0)
        XCTAssertEqual(bolus.programmed, 3.2)
        XCTAssertEqual(bolus.unabsorbed, 0.9)
    }
    
}
