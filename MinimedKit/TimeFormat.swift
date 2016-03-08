//
//  TimeFormat.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class TimeFormat: NSObject {
  static var formatterISO8601: NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierISO8601)
    formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssX"
    return formatter
  }()
    
  public static func parse2ByteDate(data: NSData, offset: Int) -> NSDateComponents {
    let comps = NSDateComponents()
    comps.day = Int(data[offset + 0] as UInt8 & UInt8(0x1f))
    comps.month = (Int(data[offset + 0] as UInt8 & UInt8(0xe0)) >> 4) +
      (Int(data[offset + 1] as UInt8 & UInt8(0x80)) >> 7)
    comps.year = 2000 + Int(data[offset + 1] as UInt8 & UInt8(0b1111111))
    return comps;
  }
  
  static func parse5ByteDate(data: NSData, offset: Int) -> NSDateComponents {
    let comps = NSDateComponents()
    comps.second = Int(data[offset + 0] as UInt8 & UInt8(0x3f))
    comps.minute = Int(data[offset + 1] as UInt8 & UInt8(0x3f))
    comps.hour = Int(data[offset + 2] as UInt8 & UInt8(0x1f))
    comps.day = Int(data[offset + 3] as UInt8 & UInt8(0x1f))
    comps.month = Int((((data[offset + 4] as UInt8) >> 4) & UInt8(0x0c)) + (data[offset + 1] as UInt8 >> 6))
    comps.year = 2000 + Int(data[offset + 4] as UInt8 & UInt8(0b1111111))
    return comps;
  }

  static func timestampStr(comps: NSDateComponents) -> String {
    let cal = NSCalendar.currentCalendar()
    cal.timeZone = NSTimeZone.localTimeZone()
    cal.locale = NSLocale.currentLocale()
    if let date = cal.dateFromComponents(comps) {
      return formatterISO8601.stringFromDate(date)
    } else {
      return "Invalid"
    }
  }
  
}
