//
//  TimestampedPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

protocol TimestampedPumpEvent: PumpEvent {
  
  var timestamp: NSDateComponents {
    get
  }
  
}
