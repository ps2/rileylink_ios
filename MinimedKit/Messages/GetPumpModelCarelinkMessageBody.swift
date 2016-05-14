//
//  GetPumpModelCarelinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class GetPumpModelCarelinkMessageBody: CarelinkLongMessageBody {
  public let model: String
  
  public required init?(rxData: NSData) {
    guard rxData.length == self.dynamicType.length,
      let mdl = String(data: rxData.subdataWithRange(NSMakeRange(2, 3)), encoding: NSASCIIStringEncoding) else {
        model = ""
        super.init(rxData: rxData)
        return nil
    }
    model = mdl
    super.init(rxData: rxData)
  }
}
