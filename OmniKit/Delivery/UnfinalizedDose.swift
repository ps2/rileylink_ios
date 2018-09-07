//
//  UnfinalizedDose.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

struct UnfinalizedDose: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    enum DoseType: Int {
        case bolus = 0
        case tempBasal
    }
    
    enum ScheduledCertainty: Int {
        case certain = 0
        case uncertain
    }
    
    let doseType: DoseType
    let units: Double
    let startTime: Date
    let duration: TimeInterval
    let scheduledCertainty: ScheduledCertainty
    
    var finishTime: Date {
        return startTime.addingTimeInterval(duration)
    }
    
    var rate: Double {
        return units / duration.hours
    }
    
    init(bolusAmount: Double, startTime: Date, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .bolus
        self.units = bolusAmount
        self.startTime = startTime
        self.duration = TimeInterval(bolusAmount / bolusDeliveryRate)
        self.scheduledCertainty = scheduledCertainty
    }
    
    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.scheduledCertainty = scheduledCertainty
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

extension NewPumpEvent {
    init(_ unfinalizedDose: UnfinalizedDose) {
        let entry: DoseEntry
        switch unfinalizedDose.doseType {
        case .bolus:
            entry = DoseEntry(type: .bolus, startDate: unfinalizedDose.startTime, value: unfinalizedDose.units, unit: .units)
        case .tempBasal:
            entry = DoseEntry(type: .tempBasal, startDate: unfinalizedDose.startTime, value: unfinalizedDose.rate, unit: .unitsPerHour)
        }
        self.init(date: unfinalizedDose.startTime, dose: entry, isMutable: false, raw: Data(), title: String(describing: unfinalizedDose))
    }
}
