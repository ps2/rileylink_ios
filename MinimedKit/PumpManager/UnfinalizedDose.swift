//
//  UnfinalizedDose.swift
//  MinimedKit
//
//  Created by Pete Schwamb on 7/31/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

public struct UnfinalizedDose: RawRepresentable, Equatable, CustomStringConvertible {
    public typealias RawValue = [String: Any]

    enum DoseType: Int {
        case bolus = 0
        case tempBasal
        case suspend
        case resume
    }

    let doseType: DoseType
    public var units: Double
    var programmedUnits: Double?     // Set when finalized; tracks programmed units
    var programmedTempRate: Double?  // Set when finalized; tracks programmed temp rate
    let startTime: Date
    var duration: TimeInterval
    var isReconciledWithHistory: Bool
    var uniqueId: UUID

    var finishTime: Date {
        get {
            return startTime.addingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSince(startTime)
        }
    }

    public var progress: Double {
        let elapsed = -startTime.timeIntervalSinceNow
        return min(elapsed / duration, 1)
    }

    public var finished: Bool {
        return progress >= 1
    }

    // Units per hour
    public var rate: Double {
        guard duration.hours > 0 else {
            return 0
        }
        
        return units / duration.hours
    }

    public var finalizedUnits: Double? {
        guard finished else {
            return nil
        }
        return units
    }

    init(bolusAmount: Double, startTime: Date, duration: TimeInterval, isReconciledWithHistory: Bool = false) {
        self.doseType = .bolus
        self.units = bolusAmount
        self.startTime = startTime
        self.duration = duration
        self.programmedUnits = nil
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID()
    }

    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval, isReconciledWithHistory: Bool = false) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.programmedUnits = nil
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID()
    }

    init(suspendStartTime: Date, isReconciledWithHistory: Bool = false) {
        self.doseType = .suspend
        self.units = 0
        self.startTime = suspendStartTime
        self.duration = 0
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID()
    }

    init(resumeStartTime: Date, isReconciledWithHistory: Bool = false) {
        self.doseType = .resume
        self.units = 0
        self.startTime = resumeStartTime
        self.duration = 0
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID()
    }

    public mutating func cancel(at date: Date) {
        guard date < finishTime else {
            return
        }

        programmedUnits = units
        let newDuration = date.timeIntervalSince(startTime)

        switch doseType {
        case .bolus:
            units = rate * newDuration.hours
        case .tempBasal:
            programmedTempRate = rate
            units = floor(rate * newDuration.hours * 20) / 20
        default:
            break
        }
        duration = newDuration
    }

    public var description: String {
        switch doseType {
        case .bolus:
            return "Bolus units:\(programmedUnits ?? units) \(startTime)"
        case .tempBasal:
            return "TempBasal rate:\(programmedTempRate ?? rate) \(startTime) duration:\(String(describing: duration))"
        default:
            return "\(String(describing: doseType).capitalized) \(startTime)"
        }
    }

    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let rawDoseType = rawValue["doseType"] as? Int,
            let doseType = DoseType(rawValue: rawDoseType),
            let units = rawValue["units"] as? Double,
            let startTime = rawValue["startTime"] as? Date,
            let duration = rawValue["duration"] as? Double
            else {
                return nil
        }

        self.doseType = doseType
        self.units = units
        self.startTime = startTime
        self.duration = duration

        if let scheduledUnits = rawValue["scheduledUnits"] as? Double {
            self.programmedUnits = scheduledUnits
        }

        if let scheduledTempRate = rawValue["scheduledTempRate"] as? Double {
            self.programmedTempRate = scheduledTempRate
        }
        
        if let uuidString = rawValue["uniqueId"] as? String {
            if let uuid = UUID(uuidString: uuidString) {
                self.uniqueId = uuid
            } else {
                return nil
            }
        } else {
            self.uniqueId = UUID()
        }

        self.isReconciledWithHistory = rawValue["isReconciledWithHistory"] as? Bool ?? false
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "doseType": doseType.rawValue,
            "units": units,
            "startTime": startTime,
            "duration": duration,
            "isReconciledWithHistory": isReconciledWithHistory,
            "uniqueId": uniqueId.uuidString,
        ]

        if let scheduledUnits = programmedUnits {
            rawValue["scheduledUnits"] = scheduledUnits
        }

        if let scheduledTempRate = programmedTempRate {
            rawValue["scheduledTempRate"] = scheduledTempRate
        }

        return rawValue
    }
}

extension NewPumpEvent {
    init(_ dose: UnfinalizedDose) {
        let title = String(describing: dose)
        let entry = DoseEntry(dose)
        let raw = dose.uniqueId.asRaw
        self.init(date: dose.startTime, dose: entry, isMutable: true, raw: raw, title: title)
    }
    
    func replacingRawAndDate(newRaw: Data, newDate: Date) -> NewPumpEvent {
        let newDose = dose?.replacingStartDate(newDate)
        return NewPumpEvent(date: newDate, dose: newDose, isMutable: isMutable, raw: newRaw, title: title, type: type)
    }
}

extension DoseEntry {
    init (_ dose: UnfinalizedDose) {
        switch dose.doseType {
        case .bolus:
            self = DoseEntry(type: .bolus, startDate: dose.startTime, endDate: dose.finishTime, value: dose.programmedUnits ?? dose.units, unit: .units, deliveredUnits: dose.finalizedUnits)
        case .tempBasal:
            self = DoseEntry(type: .tempBasal, startDate: dose.startTime, endDate: dose.finishTime, value: dose.programmedTempRate ?? dose.rate, unit: .unitsPerHour, deliveredUnits: dose.finalizedUnits)
        case .suspend:
            self = DoseEntry(suspendDate: dose.startTime)
        case .resume:
            self = DoseEntry(resumeDate: dose.startTime)
        }
    }
    
    func replacingStartDate(_ newStartDate: Date) -> DoseEntry {
        let value: Double
        switch unit {
        case .units:
            value = programmedUnits
        case .unitsPerHour:
            value = unitsPerHour
        }
        let newEndDate = max(newStartDate, endDate)
        return DoseEntry(type: type, startDate: newStartDate, endDate: newEndDate, value: value, unit: unit, deliveredUnits: deliveredUnits, description: description, syncIdentifier: syncIdentifier)
    }
}

extension Collection where Element == NewPumpEvent {
    /// find matching entry
    func firstMatchingIndex(for dose: UnfinalizedDose, within: TimeInterval) -> Self.Index? {
        return firstIndex(where: { (event) -> Bool in
            guard let type = event.type, let eventDose = event.dose, abs(eventDose.startDate.timeIntervalSince(dose.startTime)) < within else {
                return false
            }

            switch dose.doseType {
            case .bolus:
                return type == .bolus && eventDose.programmedUnits == dose.programmedUnits ?? dose.units
            case .tempBasal:
                return type == .tempBasal && eventDose.unitsPerHour == dose.programmedTempRate ?? dose.rate
            case .suspend:
                return type == .suspend
            case .resume:
                return type == .resume
            }
        })
    }
}

extension UUID {
    var asRaw: Data {
        return withUnsafePointer(to: self) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: self))
        }
    }
}
