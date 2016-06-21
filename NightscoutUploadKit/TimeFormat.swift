//
//  TimeFormat.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

class TimeFormat: NSObject {
    private static var formatterISO8601 = NSDateFormatter.ISO8601DateFormatter()

    static func timestampAsLocalDate(comps: NSDateComponents) -> NSDate? {
        let cal = comps.calendar ?? NSCalendar.currentCalendar()
        cal.timeZone = comps.timeZone ?? NSTimeZone.localTimeZone()
        return cal.dateFromComponents(comps)
    }
    
    static func timestampStr(comps: NSDateComponents) -> String {
        if let date = timestampAsLocalDate(comps) {
            return formatterISO8601.stringFromDate(date)
        } else {
            return "Invalid"
        }
    }
    
    static func timestampStrFromDate(date: NSDate) -> String {
        return formatterISO8601.stringFromDate(date)
    }
}
