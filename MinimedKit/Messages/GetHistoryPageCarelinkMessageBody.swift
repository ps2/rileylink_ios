//
//  GetHistoryPageCarelinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class GetHistoryPageCarelinkMessageBody: CarelinkLongMessageBody {
  public var lastFrame: Bool
  public var frameNumber: Int
  public var frame: NSData
  
  public required init?(rxData: NSData) {
    guard rxData.length == self.dynamicType.length else {
      frameNumber = 0
      frame = NSData()
      lastFrame = false
      super.init(rxData: rxData)
      return nil
    }
    frameNumber = Int(rxData[0] as UInt8) & 0b1111111
    lastFrame = (rxData[0] as UInt8) & 0b10000000 > 0
    frame = rxData.subdataWithRange(NSMakeRange(1, 64))
    super.init(rxData: rxData)
  }
  
  public required init(pageNum: Int) {
    let numArgs = 1
    lastFrame = false
    frame = NSData()
    frameNumber = 0
    let data = NSData(hexadecimalString: String(format: "%02x%02x", numArgs, UInt8(pageNum)))!
    super.init(rxData: data)!
  }

}