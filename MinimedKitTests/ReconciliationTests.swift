//
//  ReconciliationTests.swift
//  MinimedKitTests
//
//  Created by Pete Schwamb on 9/5/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import XCTest
import RileyLinkBLEKit
@testable import MinimedKit
import LoopKit

extension DateFormatter {
    static var descriptionFormatter: DateFormatter {
        let formatter = self.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"

        return formatter
    }
}


final class ReconciliationTests: XCTestCase {

    let testingDateFormatter = DateFormatter.descriptionFormatter

    func testingDate(_ input: String) -> Date {
        return testingDateFormatter.date(from: input)!
    }

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

    func testEricTempBasalDuration() {
        let frames = [
            "013300b663104a16001601b663104a163300b663104a16001601b663104a163300b663104a16001601b663104a1633008f78104a160016018f78104a1633009078",
            "02104a160016019078104a1601030300ae48514a163300b04f114a16001601b04f114a163300b04f114a16001601b04f114a163300b25e114a16001600b25e114a",
            "03163300b35e114a16001600b35e114a161e00836a110a161f00a946120a1601010100b34f524a1601020200b154524a1601020200b159524a1601010100a65e52",
            "044a1601020200bb63524a1601030300b468524a1601010100b76d524a1601323200916e524a163300a572124a16001601a572124a163300a672124a16001601a6",
            "0572124a163300b277124a16001600b277124a163300b377124a16001600b377124a163300ba40134a16001601ba40134a163300ba40134a16001601ba40134a16",
            "063302b04f134a16001601b04f134a163302b14f134a16001601b14f134a163300b454134a16001601b454134a163300b454134a16001601b454134a163300b268",
            "07134a16001601b268134a163300b368134a16001601b368134a163300b040144a16001601b040144a163300b140144a16001601b140144a163302a54f144a1600",
            "081601a54f144a163302a64f144a16001601a64f144a163300b054144a16001601b054144a163300b154144a16001601b154144a1633009e5e144a160016009e5e",
            "09144a1633009f5e144a160016009f5e144a163300b66d144a16001601b66d144a163300b66d144a16001601b66d144a163300b240154a16001600b240154a1633",
            "0a00b340154a16001600b340154a1601010100b345554a1601010100b14a554a1601010100b14f554a163302b45e154a16001601b45e154a163302b45e154a1600",
            "0b1601b45e154a16011c1c008f60554a163300b463154a16001601b463154a163300b463154a16001601b463154a163300b068154a16001600b068154a163300b1",
            "0c68154a16001600b168154a163300b16d154a16001601b16d154a163300b16d154a16001601b16d154a163300b245164a16001601b245164a163300b345164a16",
            "0d001601b345164a163304b259164a16001601b259164a163304b359164a16001601b359164a16330ab25e164a16001601b25e164a16330ab35e164a16001601b3",
            "0e5e164a163300a46a164a16001600a46a164a163300a56a164a16001600a56a164a1633088078164a160016018078164a163300af40174a16001601af40174a16",
            "0f3300b040174a16001601b040174a1600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a60a"
        ]

        let data = frames.reduce(Data(), { page, frameHex in
            let frameData = Data(hexadecimalString: frameHex)!
            let msg = GetHistoryPageCarelinkMessageBody(rxData: frameData)!
            return page + msg.frame
        })

        let pumpModel = PumpModel.model522

        let page = try! HistoryPage(pageData: data, pumpModel: pumpModel)

        let timezone = TimeZone(secondsFromGMT: -14400)! // GMT-0400 (fixed)

        let startDate = testingDate("2022-09-11 02:00:48 +0000")


        let (timestampedEvents, _, _) = page.timestampedEvents(after: startDate, timeZone: timezone, model: pumpModel)

        let pumpEvents = timestampedEvents.pumpEvents(from: pumpModel)

        let pendingDoses = [
            UnfinalizedDose(tempBasalRate: 0, startTime: testingDate("2022-09-11 03:00:48 +0000"), duration: 1800, insulinType: .lyumjev)
        ]

        let result = MinimedPumpManager.reconcilePendingDosesWith(pumpEvents, reconciliationMappings: [:], pendingDoses: pendingDoses)

        print("pendingDoses = \(result.pendingDoses)")
        print("reconciliationMappings = \(result.reconciliationMappings)")
        print("remainingEvents = \(result.remainingEvents)")

    }

    // Two commands issued due to unexpected response around 2022-09-14 12:31:43 +0000 (7:31:43 local time)
    // This is the history after that
    func testMultipleTempBasalCommandsIssued() {
        let frames = [
            "0116018464154d1633688869154d160016018869154d167b01884b160d161052003376ac74164d16001601ac74164d163376ac74164d16001601ac74164d16335e",
            "02b179164d16001601b179164d16335eb279164d16001601b279164d16335ab142174d16001601b142174d16335ab142174d16001601b142174d163300b151174d",
            "0316001600b151174d167b01b151170d1610520033e2a472174d16001601a472174d1633e2a572174d16001601a572174d16338e9677174d160016019677174d16",
            "04338e9777174d160016019777174d1607000001928d960726146e8d9675000000000000000192018862000a020000000000000000000a00000001600000000000",
            "05000000000000000080000000a033789640004e160016019640004e1633789640004e160016019640004e163319b650004e16001601b650004e163319b750004e",
            "0616001601b750004e163319b850004e16001601b850004e163319b850004e16001601b850004e16331aac55004e16001601ac55004e16331aad55004e16001601",
            "07ad55004e16331aae55004e16001601ae55004e16331a845a004e16001601845a004e16331bb25e004e16001601b25e004e16331bb25e004e16001601b25e004e",
            "0816331eb263004e16001601b263004e16331eb263004e16001601b263004e167b00b245010e16002a00339eac5f074e16001601ac5f074e16339ead5f074e1600",
            "091601ad5f074e16339eae5f074e16001601ae5f074e16339eb663074e16001601b663074e16339eb663074e16001601b663074e163396bb68074e16001601bb68",
            "0a074e1633968069074e160016018069074e1600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "0c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "0d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a5f8"
        ]

        let data = frames.reduce(Data(), { page, frameHex in
            let frameData = Data(hexadecimalString: frameHex)!
            let msg = GetHistoryPageCarelinkMessageBody(rxData: frameData)!
            return page + msg.frame
        })

        let pumpModel = PumpModel.model523

        let page = try! HistoryPage(pageData: data, pumpModel: pumpModel)

        let timezone = TimeZone(secondsFromGMT: -18000)! // GMT-0400 (fixed)

        let startDate = testingDate("2022-09-14 12:31:43 +0000")


        let (timestampedEvents, _, _) = page.timestampedEvents(after: startDate, timeZone: timezone, model: pumpModel)

        let pumpEvents = timestampedEvents.pumpEvents(from: pumpModel)

        let pendingDoses = [
            UnfinalizedDose(tempBasalRate: 0, startTime: testingDate("2022-09-11 03:00:48 +0000"), duration: 1800, insulinType: .lyumjev)
        ]

        let result = MinimedPumpManager.reconcilePendingDosesWith(pumpEvents, reconciliationMappings: [:], pendingDoses: pendingDoses)

        print("pendingDoses = \(result.pendingDoses)")
        print("reconciliationMappings = \(result.reconciliationMappings)")
        print("remainingEvents = \(result.remainingEvents)")

    }

}
