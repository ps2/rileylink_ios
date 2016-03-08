//
//  PumpModel.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class PumpModel: NSObject {
  
  var larger: Bool = false
  var hasLowSuspend: Bool = false
  var strokesPerUnit: Int = 10
  
  private static var base = PumpModel.init(larger:false, hasLowSuspend: false, strokesPerUnit: 10)
  private static var m523 = PumpModel.init(larger:true, hasLowSuspend: false, strokesPerUnit: 40)
  private static var m551 = PumpModel.init(larger:true, hasLowSuspend: true, strokesPerUnit: 40)

  private static var models = [
    "508": base,
    "511": base,
    "512": base,
    "515": base,
    "522": base,
    "722": base,
    "523": m523,
    "723": m523,
    "530": m523,
    "730": m523,
    "540": m523,
    "740": m523,
    "551": m551,
    "554": m551,
    "751": m551,
    "754": m551
  ]
  
  class func byModelNumber(model: String) -> PumpModel {
    return models[model]!
  }

  init(larger: Bool, hasLowSuspend: Bool, strokesPerUnit: Int) {
    self.larger = larger
    self.hasLowSuspend = hasLowSuspend
    self.strokesPerUnit = strokesPerUnit
  }
}
