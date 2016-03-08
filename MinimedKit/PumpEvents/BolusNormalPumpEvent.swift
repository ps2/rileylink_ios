//
//  BolusNormalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class BolusNormalPumpEvent: TimestampedPumpEvent {
  public let length: Int
  let timestamp: NSDateComponents
  var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
  let amount: Float
  let programmed: Float
  let unabsorbedInsulinTotal: Float
  let bolusType: String
  let duration: Int
  
  public required init?(availableData: NSData, pumpModel: PumpModel) {
    
    func d(idx:Int) -> Int {
      return Int(availableData[idx] as UInt8)
    }

    func insulinDecode(a: Int, b: Int) -> Float {
      return Float((a << 8) + b) / 40.0
    }
    
    if pumpModel.larger {
      length = 13
    } else {
      length = 9
    }
    
    if length > availableData.length {
      amount = 0
      programmed = 0
      unabsorbedInsulinTotal = 0
      duration = 0
      bolusType = "Unset"
      timestamp = NSDateComponents()
      return nil
    }
    
    if pumpModel.larger {
      timestamp = TimeFormat.parse5ByteDate(availableData, offset: 8)
      amount = insulinDecode(d(3), b: d(4))
      programmed = insulinDecode(d(1), b: d(2))
      unabsorbedInsulinTotal = insulinDecode(d(5), b: d(6))
      duration = d(7) * 30
    } else {
      timestamp = TimeFormat.parse5ByteDate(availableData, offset: 4)
      amount = Float(d(2))/10.0
      programmed = Float(d(1))/10.0
      duration = d(3) * 30
      unabsorbedInsulinTotal = 0
    }
    bolusType = duration > 0 ? "square" : "normal"
  }
  
  public var dictionaryRepresentation: [String: AnyObject] {
    var dictionary: [String: AnyObject] = [
      "_type": "BolusNormal",
      "amount": amount,
      "programmed": programmed,
      "type": bolusType,
      "timestamp": TimeFormat.timestampStr(timestamp),
    ]
    
    if let unabsorbedInsulinRecord = unabsorbedInsulinRecord {
      dictionary["appended"] = unabsorbedInsulinRecord.dictionaryRepresentation
    }
    
    if unabsorbedInsulinTotal > 0 {
      dictionary["unabsorbed"] = unabsorbedInsulinTotal
    }
    
    if duration > 0 {
      dictionary["duration"] = duration
    }
    
    return dictionary
  }

}
