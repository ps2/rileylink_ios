//
//  BasalProfileStartPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class BasalProfileStartPumpEvent: TimestampedPumpEvent {
  public let length: Int
  let timestamp: NSDateComponents
  let rate: Float
  let profileIndex: Int
  let offset: Int


  public required init?(availableData: NSData, pumpModel: PumpModel) {
    length = 10
    
    if length > availableData.length {
      timestamp = NSDateComponents()
      rate = 0
      profileIndex = 0
      offset = 0
      return nil
    }
    
    func d(idx:Int) -> Int {
      return Int(availableData[idx] as UInt8)
    }
    
    timestamp = TimeFormat.parse5ByteDate(availableData, offset: 2)
    rate = Float(d(8)) / 40.0
    profileIndex = d(1)
    offset = d(7) * 30 * 1000 * 60
  }
  
  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "_type": "BasalProfileStart",
      "timestamp": TimeFormat.timestampStr(timestamp),
      "offset": offset,
      "rate": rate,
      "profileIndex": profileIndex,
    ]
  }

}
