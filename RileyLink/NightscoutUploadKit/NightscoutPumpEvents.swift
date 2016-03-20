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
          let entry = BolusNightscoutTreatment(
            timestamp: date,
            enteredBy: eventSource,
            bolusType: bolusNormal.duration > 0 ? .Square : .Normal,
            amount: bolusNormal.amount,
            programmed: bolusNormal.programmed,
            unabsorbed: bolusNormal.unabsorbedInsulinTotal,
            duration: bolusNormal.duration)
          results.append(entry)
        }
      }
    }
    return results
  }
}

