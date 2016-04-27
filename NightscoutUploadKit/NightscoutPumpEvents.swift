//
//  NightscoutPumpEvents.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class NightscoutPumpEvents: NSObject {
  
  class func translate(events: [PumpEvent], eventSource: String) -> [NightscoutTreatment] {
    var results = [NightscoutTreatment]()
    var lastBolusWizard: BolusWizardEstimatePumpEvent?
    var lastTempBasal: TempBasalPumpEvent?
    for event in events {
      if let bgReceived = event as? BGReceivedPumpEvent {
        if let date = TimeFormat.timestampAsLocalDate(bgReceived.timestamp) {
          let entry = BGCheckNightscoutTreatment(
            timestamp: date,
            enteredBy: eventSource,
            glucose: bgReceived.amount,
            glucoseType: .Meter,
            units: .MGDL)  // TODO: can we tell this from the pump?
          results.append(entry)
        }
      }
      if let bolusNormal = event as? BolusNormalPumpEvent {
        if let date = TimeFormat.timestampAsLocalDate(bolusNormal.timestamp) {
          var carbs = 0
          var ratio = 0.0
          
          if let wizard = lastBolusWizard where wizard.timestamp == bolusNormal.timestamp {
            carbs = wizard.carbohydrates
            ratio = wizard.carbRatio
          }
          let entry = BolusNightscoutTreatment(
            timestamp: date,
            enteredBy: eventSource,
            bolusType: bolusNormal.duration > 0 ? .Square : .Normal,
            amount: bolusNormal.amount,
            programmed: bolusNormal.programmed,
            unabsorbed: bolusNormal.unabsorbedInsulinTotal,
            duration: bolusNormal.duration,
            carbs: carbs,
            ratio: ratio)
          
          results.append(entry)
        }
      }
      if let bolusWizard = event as? BolusWizardEstimatePumpEvent {
        lastBolusWizard = bolusWizard
      }
      if let tempBasal = event as? TempBasalPumpEvent {
        lastTempBasal = tempBasal
      }
      if let tempBasalDuration = event as? TempBasalDurationPumpEvent,
        tempBasal = lastTempBasal {
        
        if let date = TimeFormat.timestampAsLocalDate(tempBasal.timestamp) {
          let absolute: Double? = tempBasal.rateType == .Absolute ? tempBasal.rate : nil
          let entry = TempBasalNightscoutTreatment(
            timestamp: date,
            enteredBy: eventSource,
            temp: tempBasal.rateType == .Absolute ? .Absolute : .Percentage,
          rate: tempBasal.rate, absolute: absolute, duration: tempBasalDuration.duration)
          
          results.append(entry)
        }
      }
    }
    return results
  }
}

