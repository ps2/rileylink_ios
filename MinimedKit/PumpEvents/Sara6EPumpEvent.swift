//
//  Sara6EPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class Sara6EPumpEvent: TimestampedPumpEvent {
  
  public var length: Int
  public var timestamp: NSDateComponents
  let validDateStr: String
  
  public required init?(availableData: NSData, pumpModel: PumpModel) {
    length = 52

    // Sometimes we encounter this at the end of a page, and it can be less characters???
    // need at least 16, I think.
    if 16 > availableData.length {
      timestamp = NSDateComponents()
      validDateStr = "Invalid"
      return nil
    }
    
    let dateComponents = TimeFormat.parse2ByteDate(availableData, offset: 1)
    validDateStr = String(format: "%04d-%02d-%02d", dateComponents.year, dateComponents.month, dateComponents.day)
    timestamp = dateComponents
  }
  
  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "_type": "Sara6E",
      "timestamp": TimeFormat.timestampStr(TimeFormat.nextMidnightForDateComponents(timestamp)),
      "validDate": validDateStr,
    ]
  }
}
