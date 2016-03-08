//
//  BolusNormalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class BolusNormalPumpEvent: PumpEvent {
  public let length: Int
  
  var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
  
  public required init?(availableData: NSData, pumpModel: PumpModel) {
    
    if pumpModel.larger {
      length = 13
    } else {
      length = 9;
    }
    
    if length > availableData.length {
      return nil
    }

  }
}
