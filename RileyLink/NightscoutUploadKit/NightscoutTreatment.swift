//
//  NightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import MinimedKit

public class NightscoutTreatment : DictionaryRepresentable {
  let timestamp: NSDate
  let enteredBy: String
  
  
  init(timestamp: NSDate, enteredBy: String) {
    self.timestamp = timestamp
    self.enteredBy = enteredBy
  }
  
  public var dictionaryRepresentation: [String: AnyObject] {
    return [
      "_type": "NightscoutTreatment",
      "timestamp": TimeFormat.timestampStr(timestamp),
      "validDate": validDateStr,
    ]
  }

  
}
