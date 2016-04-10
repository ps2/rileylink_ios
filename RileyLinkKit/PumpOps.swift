//
//  PumpOps.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
import RileyLinkBLEKit


public class PumpOps: NSObject {
    
  public let pumpState: PumpState
  public let device: RileyLinkBLEDevice
  
  public init(pumpState: PumpState, device: RileyLinkBLEDevice) {
    self.pumpState = pumpState
    self.device = device
  }
  
  public func pressButton() {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
      ops.pressButton(.Down)
    }
  }
  
  public func getPumpModel(completion: (String?) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
      let model = ops.getPumpModel()
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(model)
      })
    }
  }
  
  public func getBatteryVoltage(completion: (GetBatteryCarelinkMessageBody?) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
      let response = ops.getBatteryVoltage()
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(response)
      })
    }
  }

  public func getHistoryEventsSinceDate(startDate: NSDate, completion: (Either<(events: [PumpEvent], pumpModel: PumpModel), ErrorType>) -> Void) {
    device.runSession { (session) -> Void in
      NSLog("History fetching task started.")
      let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
      do {
        let (events, pumpModel) = try ops.getHistoryEventsSinceDate(startDate)
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          completion(.Success(events: events, pumpModel: pumpModel))
        })
      } catch let error {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          completion(.Failure(error))
        })
      }
    }
  }
  
  public func tunePump(completion: (Either<FrequencyScanResults, ErrorType>) -> Void)  {
    device.runSession { (session) -> Void in
      let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
      do {
        let response = try ops.scanForPump()
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          completion(.Success(response))
        })
      } catch let error {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          completion(.Failure(error))
        })
      }
    }
  }

}
