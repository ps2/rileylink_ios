//
//  TempBasalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class TempBasalPumpEvent: PumpEvent {
  public let length: Int
  public let rateType: String
  public let rate: Double
  let timestamp: NSDateComponents

  public required init?(availableData: NSData, pumpModel: PumpModel) {
    length = 8
    
    func d(idx:Int) -> Int {
      return Int(availableData[idx] as UInt8)
    }

    if length > availableData.length {
      timestamp = NSDateComponents()
      rate = 0
      rateType = ""
      return nil
    }
    
    rateType = (d(7) >> 3) == 0 ? "absolute" : "percent"
    if rateType == "absolute" {
      rate = Double(d(1)) / 40.0
    } else {
      rate = Double(d(1))
    }

    timestamp = TimeFormat.parse5ByteDate(availableData, offset: 2)
  }

  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "_type": "TempBasal",
      "rate": rate,
      "temp": rateType,
      "timestamp": TimeFormat.timestampStr(timestamp),
    ]
  }
}
