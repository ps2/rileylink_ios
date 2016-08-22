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
        let pumpEvent = BGReceivedPumpEvent(
            availableData: NSData(hexadecimalString: "3f2122938d7510c527ad")!,
            pumpModel: PumpModel.Model523
        )!
        let timestamp = pumpEvent.timestamp
        timestamp.timeZone = NSTimeZone(forSecondsFromGMT: -5 * 60 * 60)

        let events = [
            TimestampedHistoryEvent(pumpEvent: pumpEvent, date: timestamp.date!)
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
        let pumpEvent = BolusNormalPumpEvent(
            availableData: NSData(hexadecimalString: "010080008000240009a24a1510")!,
            pumpModel: PumpModel.Model551
        )!
        let timestamp = pumpEvent.timestamp
        timestamp.timeZone = NSTimeZone(forSecondsFromGMT: -5 * 60 * 60)

        let events = [
            TimestampedHistoryEvent(pumpEvent: pumpEvent, date: timestamp.date!)
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

    func testBolusWizardAndBolusOffByOneSecond() {
        let bwEvent = BolusWizardEstimatePumpEvent(
            availableData: NSData(hexadecimalString: "5b6489340b10102850006e3c64000090000058009064")!,
            pumpModel: PumpModel.Model523
            )!

        let bolus = BolusNormalPumpEvent(
            availableData: NSData(hexadecimalString: "01009000900058008a344b1010")!,
            pumpModel: PumpModel.Model523
            )!

        let events: [TimestampedPumpEvent] = [bwEvent, bolus]
        let timezone = NSTimeZone(forSecondsFromGMT: -5 * 60 * 60)

        let timestampedEvents = events.map({ (e: TimestampedPumpEvent) -> TimestampedHistoryEvent in
            let timestamp = e.timestamp
            timestamp.timeZone = timezone
            return TimestampedHistoryEvent(pumpEvent: e, date: timestamp.date!)
        })


        let treatments = NightscoutPumpEvents.translate(timestampedEvents, eventSource: "testing")
        XCTAssertEqual(1, treatments.count)
        let treatment = treatments[0] as! BolusNightscoutTreatment
        XCTAssertEqual(treatment.amount, 3.6)
        XCTAssertEqual(treatment.bolusType, BolusNightscoutTreatment.BolusType.Normal)
        XCTAssertEqual(treatment.duration, 0)
        XCTAssertEqual(treatment.programmed, 3.6)
        XCTAssertEqual(treatment.unabsorbed, 2.2)
        XCTAssertEqual(treatment.carbs, 40)
        XCTAssertEqual(treatment.ratio, 11.0)
    }
}
