//
//  PumpEventType.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//


public enum PumpEventType: UInt8 {
  case BolusNormal = 0x01
  case UnabsorbedInsulin = 0x5c
  case Sara6E = 0x6e
  case BolusWizardEstimate = 0x5b
  
  var eventType: PumpEvent.Type {
    switch self {
    case .UnabsorbedInsulin:
      return UnabsorbedInsulinPumpEvent.self
    case .BolusNormal:
      return BolusNormalPumpEvent.self
    case .Sara6E:
      return Sara6EPumpEvent.self
    case .BolusWizardEstimate:
      return BolusWizardEstimatePumpEvent.self
    }
  }
}

