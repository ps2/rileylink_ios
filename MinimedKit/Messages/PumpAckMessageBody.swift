//
//  PumpAckMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class PumpAckMessageBody: MessageBody {
  public static let length = 1
  
  let rxData: NSData
  
  public required init?(rxData: NSData) {
    self.rxData = rxData
  }
  
  public var txData: NSData {
    return rxData
  }
}