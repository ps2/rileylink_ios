//
//  BasalScheduleTests.swift
//  RileyLink
//
//  Created by Jaim Zuber on 5/2/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit

class BasalScheduleTests: XCTestCase {

    func testBasicConversion() {
        let sampleDataString = "06000052000178050202000304000402000504000602000704000802000904000a02000b04000c02000d02000e02000f040010020011040012020013040014020015040016020017040018020019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        
        let rxData = Data(hexadecimalString: sampleDataString)!
        let profile = BasalSchedule(data: rxData)
        
        XCTAssertEqual(profile.entries.count, 26)
        
        let basalSchedule = profile.entries
        
        // Test each element
        XCTAssertEqual(basalSchedule[0].index, 0)
        XCTAssertEqual(basalSchedule[0].timeOffset, TimeInterval(minutes: 0))
        XCTAssertEqual(basalSchedule[0].rate, 0.15, accuracy: .ulpOfOne)
        
        XCTAssertEqual(basalSchedule[1].index, 1)
        XCTAssertEqual(basalSchedule[1].timeOffset, TimeInterval(minutes: 30))
        XCTAssertEqual(basalSchedule[1].rate, 2.05, accuracy: .ulpOfOne)
        
        // Tests parsing rates that take two bytes to encode
        XCTAssertEqual(basalSchedule[2].index, 2)
        XCTAssertEqual(basalSchedule[2].timeOffset, TimeInterval(minutes: 60))
        XCTAssertEqual(basalSchedule[2].rate, 35.00, accuracy: .ulpOfOne)
        
        // Tests parsing entry on the second page
        XCTAssertEqual(basalSchedule[25].index, 25)
        XCTAssertEqual(basalSchedule[25].timeOffset, TimeInterval(minutes: 750))
        XCTAssertEqual(basalSchedule[25].rate, 0.05, accuracy: .ulpOfOne)
    }
}
