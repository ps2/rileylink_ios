//
//  PumpModel.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

public class PumpModel {
  
  public let larger: Bool
  public let hasLowSuspend: Bool
  public let strokesPerUnit: Int
  public let name: String
  
  private static let models = [
    "508": PumpModel.init(name: "508"),
    "511": PumpModel.init(name: "511"),
    "512": PumpModel.init(name: "512"),
    "515": PumpModel.init(name: "515"),
    "522": PumpModel.init(name: "522"),
    "722": PumpModel.init(name: "722"),
    "523": PumpModel.init(larger:true, strokesPerUnit: 40, name: "523"),
    "723": PumpModel.init(larger:true, strokesPerUnit: 40, name: "723"),
    "530": PumpModel.init(larger:true, strokesPerUnit: 40, name: "530"),
    "730": PumpModel.init(larger:true, strokesPerUnit: 40, name: "730"),
    "540": PumpModel.init(larger:true, strokesPerUnit: 40, name: "540"),
    "740": PumpModel.init(larger:true, strokesPerUnit: 40, name: "740"),
    "551": PumpModel.init(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "554": PumpModel.init(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "751": PumpModel.init(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "754": PumpModel.init(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551")
  ]
  
  public class func byModelNumber(model: String) -> PumpModel {
    return models[model]!
  }

  init(larger: Bool = false, hasLowSuspend: Bool = false, strokesPerUnit: Int = 10, name: String) {
    self.larger = larger
    self.hasLowSuspend = hasLowSuspend
    self.strokesPerUnit = strokesPerUnit
    self.name = name
  }
}
