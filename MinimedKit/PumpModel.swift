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
    "508": PumpModel(name: "508"),
    "511": PumpModel(name: "511"),
    "512": PumpModel(name: "512"),
    "515": PumpModel(name: "515"),
    "522": PumpModel(name: "522"),
    "722": PumpModel(name: "722"),
    "523": PumpModel(larger:true, strokesPerUnit: 40, name: "523"),
    "723": PumpModel(larger:true, strokesPerUnit: 40, name: "723"),
    "530": PumpModel(larger:true, strokesPerUnit: 40, name: "530"),
    "730": PumpModel(larger:true, strokesPerUnit: 40, name: "730"),
    "540": PumpModel(larger:true, strokesPerUnit: 40, name: "540"),
    "740": PumpModel(larger:true, strokesPerUnit: 40, name: "740"),
    "551": PumpModel(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "554": PumpModel(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "751": PumpModel(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551"),
    "754": PumpModel(larger:true, hasLowSuspend: true, strokesPerUnit: 40, name: "551")
  ]
  
  public class func byModelNumber(model: String) -> PumpModel? {
    return models[model]
  }

  init(larger: Bool = false, hasLowSuspend: Bool = false, strokesPerUnit: Int = 10, name: String) {
    self.larger = larger
    self.hasLowSuspend = hasLowSuspend
    self.strokesPerUnit = strokesPerUnit
    self.name = name
  }
}
