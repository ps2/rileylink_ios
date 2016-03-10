//
//  NightScoutPumpEvents.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class NightScoutPumpEvents: NSObject {
  
  class func translate(events: [PumpEvent]) -> [[String: AnyObject]] {
    var results = [[String: AnyObject]]()
    for event in events {
      
      if let bgReceived = event as? BGReceivedPumpEvent {
        let entry: [String: AnyObject] = [
          "eventType": "<none>",
          "glucose": bgReceived.amount,
          "glucoseType": "Finger",
          "notes": "Pump received finger stick."
        ]
        results.append(entry)
      }
    }
    return results
  }  
}
