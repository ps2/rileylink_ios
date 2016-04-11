//
//  PumpState.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit


public class PumpState: NSObject {
  public let pumpID: String
  public var timeZone: NSTimeZone = NSTimeZone.localTimeZone()
  public var pumpModel: PumpModel?
  public var lastHistoryDump: NSDate?
  public var awakeUntil: NSDate?

  public init(pumpID: String) {
    self.pumpID = pumpID

    super.init()
  }

  public var isAwake: Bool {
    return awakeUntil?.timeIntervalSinceNow > 0
  }
}
