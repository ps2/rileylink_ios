//
//  NightscoutPumpEvents.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit

class NightscoutPumpEvents: NSObject {
    
    class func translate(events: [TimestampedHistoryEvent], eventSource: String) -> [NightscoutTreatment] {
        var results = [NightscoutTreatment]()
        var lastBolusWizard: BolusWizardEstimatePumpEvent?
        var lastTempBasal: TempBasalPumpEvent?
        for event in events {
            switch event.pumpEvent {
            case let bgReceived as BGReceivedPumpEvent:
                let entry = BGCheckNightscoutTreatment(
                    timestamp: event.date,
                    enteredBy: eventSource,
                    glucose: bgReceived.amount,
                    glucoseType: .Meter,
                    units: .MGDL)  // TODO: can we tell this from the pump?
                results.append(entry)
            case let bolusNormal as BolusNormalPumpEvent:
                var carbs = 0
                var ratio = 0.0
                
                if let wizard = lastBolusWizard where wizard.timestamp == bolusNormal.timestamp {
                    carbs = wizard.carbohydrates
                    ratio = wizard.carbRatio
                }
                let entry = BolusNightscoutTreatment(
                    timestamp: event.date,
                    enteredBy: eventSource,
                    bolusType: bolusNormal.duration > 0 ? .Square : .Normal,
                    amount: bolusNormal.amount,
                    programmed: bolusNormal.programmed,
                    unabsorbed: bolusNormal.unabsorbedInsulinTotal,
                    duration: bolusNormal.duration,
                    carbs: carbs,
                    ratio: ratio)
                
                results.append(entry)
            case let bolusWizard as BolusWizardEstimatePumpEvent:
                lastBolusWizard = bolusWizard
            case let tempBasal as TempBasalPumpEvent:
                lastTempBasal = tempBasal
            case let tempBasalDuration as TempBasalDurationPumpEvent:
                if let tempBasal = lastTempBasal {
                    let absolute: Double? = tempBasal.rateType == .Absolute ? tempBasal.rate : nil
                    let entry = TempBasalNightscoutTreatment(
                        timestamp: event.date,
                        enteredBy: eventSource,
                        temp: tempBasal.rateType == .Absolute ? .Absolute : .Percentage,
                        rate: tempBasal.rate, absolute: absolute, duration: tempBasalDuration.duration)
                    
                    results.append(entry)
                }
            default:
                break
            }
        }
        return results
    }
}

