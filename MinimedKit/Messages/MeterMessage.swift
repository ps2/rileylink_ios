//
//  MeterMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class MeterMessage {

  let length = 6
  
  public let glucose: Int
  public let ackFlag: Bool
  let rxData: NSData
  
  public required init?(rxData: NSData) {
    self.rxData = rxData
    
    if rxData.length == length,
      let packetType = PacketType(rawValue: rxData[0]) where packetType == .Meter
    {
      let flags = ((rxData[4] as UInt8) & 0b110) >> 1
      ackFlag = flags == 0x03
      glucose = Int((rxData[4] as UInt8) & 0b1) << 8 + Int(rxData[4] as UInt8)
    } else {
      ackFlag = false
      glucose = 0
      return nil
    }
  }
  
  public var txData: NSData {
    return rxData
  }
  
  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "glucose": glucose,
      "ackFlag": ackFlag,
    ]
  }
}
