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

    private static let dateFormatter = ISO8601DateFormatter()

    fileprivate var uniqueKey: Data {
        return "\(doseType) \(scheduledUnits ?? units) \(UnfinalizedDose.dateFormatter.string(from: startTime))".data(using: .utf8)!
    }

    let doseType: DoseType
    public var units: Double
    var scheduledUnits: Double?     // Set when finalized; tracks original scheduled units
    var scheduledTempRate: Double?  // Set when finalized; tracks the original temp rate
    let startTime: Date
    var duration: TimeInterval
    var isReconciledWithHistory: Bool
    var uniqueId: String

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
        self.scheduledUnits = nil
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID().uuidString
    }

    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval, isReconciledWithHistory: Bool = false) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.scheduledUnits = nil
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID().uuidString
    }

    init(suspendStartTime: Date, isReconciledWithHistory: Bool = false) {
        self.doseType = .suspend
        self.units = 0
        self.startTime = suspendStartTime
        self.duration = 0
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID().uuidString
    }

    init(resumeStartTime: Date, isReconciledWithHistory: Bool = false) {
        self.doseType = .resume
        self.units = 0
        self.startTime = resumeStartTime
        self.duration = 0
        self.isReconciledWithHistory = isReconciledWithHistory
        self.uniqueId = UUID().uuidString
    }

    public mutating func cancel(at date: Date) {
        guard date < finishTime else {
            return
        }

        scheduledUnits = units
        let newDuration = date.timeIntervalSince(startTime)

        switch doseType {
        case .bolus:
            units = rate * newDuration.hours
        case .tempBasal:
            scheduledTempRate = rate
            units = floor(rate * newDuration.hours * 20) / 20
        default:
            break
        }
        duration = newDuration
    }

    public var description: String {
        switch doseType {
        case .bolus:
            return "Bolus units:\(scheduledUnits ?? units) \(startTime)"
        case .tempBasal:
            return "TempBasal rate:\(scheduledTempRate ?? rate) \(startTime) duration:\(String(describing: duration))"
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
            self.scheduledUnits = scheduledUnits
        }

        if let scheduledTempRate = rawValue["scheduledTempRate"] as? Double {
            self.scheduledTempRate = scheduledTempRate
        }
        
        if let uniqueId = rawValue["uniqueId"] as? String {
            self.uniqueId = uniqueId
        } else {
            self.uniqueId = UUID().uuidString
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
            "uniqueId": uniqueId,
        ]

        if let scheduledUnits = scheduledUnits {
            rawValue["scheduledUnits"] = scheduledUnits
        }

        if let scheduledTempRate = scheduledTempRate {
            rawValue["scheduledTempRate"] = scheduledTempRate
        }

        return rawValue
    }
}

extension NewPumpEvent {
    init(_ dose: UnfinalizedDose) {
        let title = String(describing: dose)
        let entry = DoseEntry(dose)
        self.init(date: dose.startTime, dose: entry, isMutable: true, raw: dose.uniqueKey, title: title)
    }
    
    func replacingDose(_ newDose: DoseEntry?) -> NewPumpEvent {
        return NewPumpEvent(date: date, dose: newDose, isMutable: isMutable, raw: raw, title: title, type: type)
    }
}

extension DoseEntry {
    init (_ dose: UnfinalizedDose) {
        switch dose.doseType {
        case .bolus:
            self = DoseEntry(type: .bolus, startDate: dose.startTime, endDate: dose.finishTime, value: dose.scheduledUnits ?? dose.units, unit: .units, deliveredUnits: dose.finalizedUnits)
        case .tempBasal:
            self = DoseEntry(type: .tempBasal, startDate: dose.startTime, endDate: dose.finishTime, value: dose.scheduledTempRate ?? dose.rate, unit: .unitsPerHour, deliveredUnits: dose.finalizedUnits)
        case .suspend:
            self = DoseEntry(suspendDate: dose.startTime)
        case .resume:
            self = DoseEntry(resumeDate: dose.startTime)
        }
    }
    
    func replacingSyncIdentifier(_ newSyncIdentifier: String?) -> DoseEntry {
        let value: Double
        switch unit {
        case .units:
            value = programmedUnits
        case .unitsPerHour:
            value = unitsPerHour
        }
        return DoseEntry(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, deliveredUnits: deliveredUnits, description: description, syncIdentifier: newSyncIdentifier)
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
                return type == .bolus && eventDose.programmedUnits == dose.scheduledUnits ?? dose.units
            case .tempBasal:
                return type == .tempBasal && eventDose.unitsPerHour == dose.scheduledTempRate ?? dose.rate
            case .suspend:
                return type == .suspend
            case .resume:
                return type == .resume
            }
        })
    }
}
