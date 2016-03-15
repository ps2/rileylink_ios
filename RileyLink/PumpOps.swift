//
//  PumpOps.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class PumpOps: NSObject {
  
  var pumpState: PumpState
  var device: RileyLinkBLEDevice
  
  init(pumpState: PumpState, device: RileyLinkBLEDevice) {
    self.pumpState = pumpState
    self.device = device
  }
  
  func pressButton() {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous.init(pumpState: self.pumpState, session: session)
      ops.pressButton(.Down)
    }
  }
  
  func getPumpModel(completion: (String?) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous.init(pumpState: self.pumpState, session: session)
      let model = ops.getPumpModel()
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(model)
      })
    }
  }
  
  func getBatteryVoltage(completion: (GetBatteryCarelinkMessageBody?) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous.init(pumpState: self.pumpState, session: session)
      let response = ops.getBatteryVoltage()
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(response)
      })
    }
  }
  
  func getHistoryPage(page: Int, completion: (HistoryFetchResults) -> Void)  {
    var historyTask: UIBackgroundTaskIdentifier? = nil
    historyTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { () -> Void in
      NSLog("History fetching task expired.")
      UIApplication.sharedApplication().endBackgroundTask(historyTask!)
    }
    device.runSession { (session) -> Void in
      NSLog("History fetching task expired.")
      let ops = PumpOpsSynchronous.init(pumpState: self.pumpState, session: session)
      let response = ops.getHistoryPage(page)
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(response)
        UIApplication.sharedApplication().endBackgroundTask(historyTask!)
      })
      NSLog("History fetching task completed normally.")
    }
  }
  
  func tunePump(completion: (FrequencyScanResults) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous.init(pumpState: self.pumpState, session: session)
      let response = ops.scanForPump()
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(response)
      })
    }
  }

}
