//
//  ResultDailyTotalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class ResultDailyTotalPumpEvent: PumpEvent {
  public let length: Int
  let timestamp: NSDateComponents
  let validDateStr: String

  public required init?(availableData: NSData, pumpModel: PumpModel) {
    
    if pumpModel.larger {
      length = 10
    } else {
      length = 7
    }

    if length > availableData.length {
      timestamp = NSDateComponents()
      validDateStr = "Invalid"
      return nil
    }

    let dateComponents = TimeFormat.parse2ByteDate(availableData, offset: 5)
    validDateStr = String(format: "%04d-%02d-%02d", dateComponents.year, dateComponents.month, dateComponents.day)
    timestamp = TimeFormat.midnightForDate(dateComponents)
  }

  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "_type": "ResultDailyTotal",
      "timestamp": TimeFormat.timestampStr(timestamp),
      "validDate": validDateStr,
    ]
  }
}
