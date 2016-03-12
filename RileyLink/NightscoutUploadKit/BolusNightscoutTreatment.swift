//
//  BolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class BolusNightscoutTreatment: NightscoutTreatment {
  
  enum BolusType: String {
    case Normal = "normal"
    case Square = "square"
    case DualWave = "dual"
  }
  
  let bolusType: BolusType
  let amount: Double
  let programmed: Double
  let unabsorbed: Double
  let duration: Int
  
  init(timestamp: NSDate, enteredBy: String, bolusType: BolusType, amount: Double, programmed: Double, unabsorbed: Double, duration: Int) {
    self.bolusType = bolusType
    self.amount = amount
    self.programmed = programmed
    self.unabsorbed = unabsorbed
    self.duration = duration
    super.init(timestamp: timestamp, enteredBy: enteredBy)
  }
  
  override public var dictionaryRepresentation: [String: AnyObject] {
    var rval = super.dictionaryRepresentation
    rval["type"] = bolusType.rawValue
    rval["amount"] = amount
    rval["programmed"] = programmed
    rval["unabsorbed"] = unabsorbed
    rval["duration"] = duration
    return rval
  }
}
