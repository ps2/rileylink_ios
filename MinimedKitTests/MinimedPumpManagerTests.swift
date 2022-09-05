//
//  MinimedPumpManagerTests.swift
//  MinimedKitTests
//
//  Created by Pete Schwamb on 5/3/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import XCTest
import RileyLinkBLEKit
@testable import MinimedKit
import LoopKit

class MinimedPumpManagerTests: XCTestCase {

    func testPendingDoseUpdatesWithActualDeliveryFromHistoryDose() {
        
        let bolusTime = Date().addingTimeInterval(-TimeInterval(minutes: 5));
        
        let bolusEventTime = bolusTime.addingTimeInterval(2)

        let cancelTime = bolusEventTime.addingTimeInterval(TimeInterval(minutes: 1))

        let unfinalizedBolus = UnfinalizedDose(bolusAmount: 5.4, startTime: bolusTime, duration: TimeInterval(200), insulinType: .novolog, automatic: false, isReconciledWithHistory: false)
        
        // 5.4 bolus interrupted at 1.0 units
        let eventDose = DoseEntry(type: .bolus, startDate: bolusEventTime, endDate: cancelTime, value: unfinalizedBolus.units, unit: .units, deliveredUnits: 1.0)
        
        let bolusEvent = NewPumpEvent(
            date: bolusEventTime,
            dose: eventDose,
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
    }
    
    func testReconciledDosesShouldOnlyAppearInReturnedPendingDoses() {
        
        let bolusTime = Date().addingTimeInterval(-TimeInterval(minutes: 5));

        // Shows up in history 2 seconds later
        let bolusEventTime = bolusTime.addingTimeInterval(2)
        
        let bolusAmount = 1.5
        
        let bolusDuration = PumpModel.model523.bolusDeliveryTime(units: bolusAmount)

        let unfinalizedBolus = UnfinalizedDose(bolusAmount: bolusAmount, startTime: bolusTime, duration: bolusDuration, insulinType: .novolog, automatic: false, isReconciledWithHistory: false)
        
        let eventDose = DoseEntry(type: .bolus, startDate: bolusEventTime, endDate: bolusEventTime.addingTimeInterval(bolusDuration), value: bolusAmount, unit: .units, deliveredUnits: bolusAmount)
        
        let bolusEvent = NewPumpEvent(
            date: bolusEventTime,
            dose: eventDose,
            raw: Data(hexadecimalString: "abcdef")!,
            title: "Test Bolus",
            type: .bolus)
        
        let result = MinimedPumpManager.reconcilePendingDosesWith([bolusEvent], reconciliationMappings: [:], pendingDoses: [unfinalizedBolus])
        
        // Should mark pending bolus as reconciled
        XCTAssertEqual(1, result.pendingDoses.count)
        let pendingBolus = result.pendingDoses.first!
        XCTAssertEqual(true, pendingBolus.isReconciledWithHistory)
        
        XCTAssertEqual(1, result.reconciliationMappings.count)
        XCTAssertEqual(unfinalizedBolus.uuid, result.reconciliationMappings[bolusEvent.raw]?.uuid)
        XCTAssertEqual(unfinalizedBolus.startTime, result.reconciliationMappings[bolusEvent.raw]?.startTime)

        // Bolus should not be returned as history event
        XCTAssert(result.remainingEvents.isEmpty)
    }
    
    func testReconciledDosesShouldNotAppearInReturnedPumpEvents() {
        
        let bolusTime = Date().addingTimeInterval(-TimeInterval(minutes: 5));

        // Shows up in history 2 seconds later
        let bolusEventTime = bolusTime.addingTimeInterval(2)
        
        let bolusAmount = 1.5
        
        let bolusDuration = PumpModel.model523.bolusDeliveryTime(units: bolusAmount)

        let eventDose = DoseEntry(type: .bolus, startDate: bolusEventTime, endDate: bolusEventTime.addingTimeInterval(bolusDuration), value: bolusAmount, unit: .units, deliveredUnits: bolusAmount)
        
        let bolusEvent = NewPumpEvent(
            date: bolusEventTime,
            dose: eventDose,
            raw: Data(hexadecimalString: "abcdef")!,
            title: "Test Bolus",
            type: .bolus)
        
        
        
        let reconciliationMappings: [Data:ReconciledDoseMapping] = [
            bolusEvent.raw : ReconciledDoseMapping(startTime: bolusTime, uuid: UUID(), eventRaw: bolusEvent.raw)
        ]
        
        let result = MinimedPumpManager.reconcilePendingDosesWith([bolusEvent], reconciliationMappings: reconciliationMappings, pendingDoses: [])
        
        // Bolus should not be returned as history event
        XCTAssert(result.remainingEvents.isEmpty)
    }

    class MockRileyLinkProvider: RileyLinkDeviceProvider {
        func getDevices(_ completion: @escaping ([RileyLinkBLEKit.RLDevProtocol]) -> Void) {
            <#code#>
        }


        init() {

        }

        var idleListeningEnabled: Bool

        var timerTickEnabled: Bool

        func deprioritize(_ device: RileyLinkBLEKit.RileyLinkDevice, completion: (() -> Void)?) {
            <#code#>
        }

        func assertIdleListening(forcingRestart: Bool) {
            <#code#>
        }

        var idleListeningState: RileyLinkBLEKit.RileyLinkDevice.IdleListeningState

        var debugDescription: String = ""
    }

    func testReportingBolusBeforeReconciliation() {
        let rlProvider = MockRileyLinkProvider()
        let rlManagerState = RileyLinkConnectionManagerState(autoConnectIDs: [])
        let state = MinimedPumpManagerState(isOnboarded: true, useMySentry: true, pumpColor: .blue, pumpID: "123456", pumpModel: .model523, pumpFirmwareVersion: "VER 2.4A1.1", pumpRegion: .northAmerica, rileyLinkConnectionManagerState: rlManagerState, timeZone: .currentFixed, suspendState: .resumed(Date()), insulinType: .novolog)
        let manager = MinimedPumpManager(state: state, rileyLinkDeviceProvider: <#T##RileyLinkDeviceProvider#>)
    }

}
