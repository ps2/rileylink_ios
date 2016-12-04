//
//  GlucoseEventTimestamperTests.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 12/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class GlucoseEventTimestamperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    func pageOneData() -> [GlucoseEvent] {
        return [
            GlucoseSensorDataGlucoseEvent(availableData: Data(hexadecimalString: "30")!)!,
            SensorTimestampGlucoseEvent(availableData: Data(hexadecimalString: "0814B62810")!)!,
            GlucoseSensorDataGlucoseEvent(availableData: Data(hexadecimalString: "34")!)!,
            NineteenSomethingGlucoseEvent(availableData: Data(hexadecimalString: "13")!)!,
            BatteryChangeGlucoseEvent(availableData: Data(hexadecimalString: "0A0BAE0A0E")!)!,
            GlucoseSensorDataGlucoseEvent(availableData: Data(hexadecimalString: "30")!)!
        ];
    }
    
    func testRelativeTimestampThatHasNoReference() {
        let events = pageOneData();
        let (processedEvents: processedEvents, unprocessedEvents: unprocessedEvents) = GlucoseEventTimestamper.addTimestampsToEvents(events: events);
        XCTAssertEqual(1, unprocessedEvents.count)
        XCTAssertEqual(5, processedEvents.count)
    }
    
    func testReferenceTimestampKeepsTimestamp() {
        let events = pageOneData();
        let (processedEvents: processedEvents, unprocessedEvents: _) = GlucoseEventTimestamper.addTimestampsToEvents(events: events);
        
        //the initial timestamp comes from the sensor timestamp reference record
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2016, month: 2, day: 8,
                                               hour: 20, minute: 54)
        XCTAssertEqual(processedEvents[0].timestamp, expectedTimestamp)
    }
    
    func testIndependentTimestampKeepsTimestamp() {
        let events = pageOneData();
        let (processedEvents: processedEvents, unprocessedEvents: _) = GlucoseEventTimestamper.addTimestampsToEvents(events: events);
        
        
        let expectedTimestamp = DateComponents(calendar: Calendar.current,
                                               year: 2014, month: 2, day: 10, hour: 11, minute: 46)
        XCTAssertEqual(processedEvents[3].timestamp, expectedTimestamp)
    }
    
    func testRelativeTimestampsAfterReferenceEvent() {
        let calendar = Calendar.current
        let events = pageOneData();
        let (processedEvents: processedEvents, unprocessedEvents: _) = GlucoseEventTimestamper.addTimestampsToEvents(events: events);
        
        let expectedFirstGlucoseTimestamp = DateComponents(calendar: calendar,
                                               year: 2016, month: 2, day: 8,
                                               hour: 20, minute: 59)
        
        //SGV increments the time by 5 minutes
        XCTAssertEqual(processedEvents[1].timestamp, expectedFirstGlucoseTimestamp)
        
        //19-Something doesn't increment the time
        XCTAssertEqual(processedEvents[2].timestamp, expectedFirstGlucoseTimestamp)
        
        let expectedSecondGlucoseTimestamp = DateComponents(calendar: calendar,
                                                            year: 2016, month: 2, day: 8,
                                                            hour: 21, minute: 04)
        //SGV increments the time by 5 minutes
        XCTAssertEqual(processedEvents[4].timestamp, expectedSecondGlucoseTimestamp)
    }
}
