//
//  UnabsorbedInsulinPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class UnabsorbedInsulinPumpEvent: PumpEvent {
  public let length: Int
  
  public required init?(availableData: NSData, pumpModel: PumpModel) {
    length = Int(max(availableData[1] as UInt8, UInt8(2)))
    
    if length < availableData.length {
      return nil
    }

  }
}
