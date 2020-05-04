//
//  MinimedPumpManagerTests.swift
//  MinimedKitTests
//
//  Created by Pete Schwamb on 5/3/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit
import LoopKit

class MinimedPumpManagerTests: XCTestCase {

    func testEventReconciliation() {
        
        let bolusTime = Date().addingTimeInterval(-TimeInterval(minutes: 5));
        
        let bolusEventTime = bolusTime.addingTimeInterval(2)

        let cancelTime = bolusEventTime.addingTimeInterval(TimeInterval(minutes: 1))

        let unfinalizedBolus = UnfinalizedDose(bolusAmount: 5.4, startTime: bolusTime, duration: TimeInterval(200), isReconciledWithHistory: false)
        
        // 5.4 bolus interrupted at 1.0 units
        let eventDose = DoseEntry(type: .bolus, startDate: bolusEventTime, endDate: cancelTime, value: unfinalizedBolus.units, unit: .units, deliveredUnits: 1.0)
        
        let bolusEvent = NewPumpEvent(
            date: bolusEventTime,
            dose: eventDose,
            isMutable: false,
            raw: Data(hexadecimalString: "abcdef")!,
            title: "Test Bolus",
            type: .bolus)
        
        let result = MinimedPumpManager.reconcilePendingDosesWith([bolusEvent], reconciliationMappings: [:], pendingDoses: [unfinalizedBolus])
        
        // Should mark pending bolus as reconciled
        XCTAssertEqual(1, result.pendingDoses.count)
        let pendingBolus = result.pendingDoses.first!
        XCTAssertEqual(true, pendingBolus.isReconciledWithHistory)
        
        // Pending bolus should be updated with actual delivery amount
        XCTAssertEqual(1.0, pendingBolus.units)
        XCTAssertEqual(5.4, pendingBolus.programmedUnits)
        XCTAssertEqual(TimeInterval(minutes: 1), pendingBolus.duration)
        XCTAssertEqual(true, pendingBolus.isFinished)

        // Should update event with uuid from pending
        XCTAssertEqual(1, result.reconciledEvents.count)
        let reconciledEvent = result.reconciledEvents.first!
        XCTAssertEqual(pendingBolus.uuid.asRaw, reconciledEvent.raw)

        XCTAssertEqual(1.0, reconciledEvent.dose!.deliveredUnits)
    }
}
