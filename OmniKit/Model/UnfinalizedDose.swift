//
//  UnfinalizedDose.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

public struct UnfinalizedDose: RawRepresentable, Equatable, CustomStringConvertible {
    public typealias RawValue = [String: Any]

    enum DoseType: Int {
        case bolus = 0
        case tempBasal
    }
    
    enum ScheduledCertainty: Int {
        case certain = 0
        case uncertain
        
        public var localizedDescription: String {
            switch self {
            case .certain:
                return LocalizedString("Certain", comment: "String describing a dose that was certainly scheduled")
            case .uncertain:
                return LocalizedString("Uncertain", comment: "String describing a dose that was possibly scheduled")
            }
        }
    }
    
    private var insulinFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .medium
        return timeFormatter
    }

    
    let doseType: DoseType
    var units: Double
    var scheduledUnits: Double?
    let startTime: Date
    var duration: TimeInterval
    var scheduledCertainty: ScheduledCertainty
    
    var finishTime: Date {
        get {
            return startTime.addingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSince(startTime)
        }
    }
    
    // Units per hour
    var rate: Double {
        return units / duration.hours
    }
    
    init(bolusAmount: Double, startTime: Date, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .bolus
        self.units = bolusAmount
        self.startTime = startTime
        self.duration = TimeInterval(bolusAmount / bolusDeliveryRate)
        self.scheduledCertainty = scheduledCertainty
        self.scheduledUnits = nil
    }
    
    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.scheduledCertainty = scheduledCertainty
        self.scheduledUnits = nil
    }
    
    public mutating func cancel(at date: Date) {
        scheduledUnits = units
        let oldRate = rate
        duration = date.timeIntervalSince(startTime)
        units = oldRate * duration.hours
    }
    
    public var description: String {
        let unitsStr = insulinFormatter.string(from: units) ?? "?"
        let startTimeStr = dateFormatter.string(from: startTime)
        let durationStr = duration.format(using: [.minute, .second]) ?? "?"
        switch doseType {
        case .bolus:
            if let scheduledUnits = scheduledUnits {
                let scheduledUnitsStr = insulinFormatter.string(from: scheduledUnits) ?? "?"
                return String(format: LocalizedString("InterruptedBolus: %1$@ U (%2$@ U scheduled) %3$@ %4$@ %5$@", comment: "The format string describing a bolus that was interrupted. (1: The amount delivered)(2: The amount scheduled)(3: Start time of the dose)(4: duration)(5: scheduled certainty)"), unitsStr, scheduledUnitsStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
            } else {
                return String(format: LocalizedString("Bolus: %1$@U %2$@ %3$@ %4$@", comment: "The format string describing a bolus. (1: The amount delivered)(2: Start time of the dose)(3: duration)(4: scheduled certainty)"), unitsStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
            }
        case .tempBasal:
            let rateStr = NumberFormatter.localizedString(from: NSNumber(value: rate), number: .decimal)
            return String(format: LocalizedString("TempBasal: %1$@ U/hour %2$@ for %3$@ %4$@", comment: "The format string describing a temp basal. (1: The rate)(2: Start time)(3: duration)(4: scheduled certainty"), rateStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
        }
    }
    
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let rawDoseType = rawValue["doseType"] as? Int,
            let doseType = DoseType(rawValue: rawDoseType),
            let units = rawValue["units"] as? Double,
            let startTime = rawValue["startTime"] as? Date,
            let duration = rawValue["duration"] as? Double,
            let rawScheduledCertainty = rawValue["scheduledCertainty"] as? Int,
            let scheduledCertainty = ScheduledCertainty(rawValue: rawScheduledCertainty)
            else {
                return nil
        }
        self.doseType = doseType
        self.units = units
        self.startTime = startTime
        self.duration = TimeInterval(duration)
        self.scheduledCertainty = scheduledCertainty
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "doseType": doseType.rawValue,
            "units": units,
            "startTime": startTime,
            "duration": duration,
            "scheduledCertainty": scheduledCertainty.rawValue
            ]
        
        return rawValue
    }
}

private extension TimeInterval {
    func format(using units: NSCalendar.Unit) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = units
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropLeading
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: self)
    }
}

extension NewPumpEvent {
    init(_ unfinalizedDose: UnfinalizedDose) {
        let title = String(describing: unfinalizedDose)
        let entry: DoseEntry
        switch unfinalizedDose.doseType {
        case .bolus:
            entry = DoseEntry(type: .bolus, startDate: unfinalizedDose.startTime, value: unfinalizedDose.units, unit: .units)
        case .tempBasal:
            entry = DoseEntry(type: .tempBasal, startDate: unfinalizedDose.startTime, endDate: unfinalizedDose.finishTime, value: unfinalizedDose.rate, unit: .unitsPerHour)
        }
        self.init(date: unfinalizedDose.startTime, dose: entry, isMutable: false, raw: title.data(using: .utf8)!, title: title)
    }
}
