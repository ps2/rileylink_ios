//
//  TimeFormat.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class TimeFormat: NSObject {
    private static var formatterISO8601: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierISO8601)
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssX"
        return formatter
    }()

    public static func timestampAsLocalDate(comps: NSDateComponents) -> NSDate? {
        let cal = comps.calendar ?? NSCalendar.currentCalendar()
        cal.timeZone = comps.timeZone ?? NSTimeZone.localTimeZone()
        return cal.dateFromComponents(comps)
    }
    
    public static func timestampStr(comps: NSDateComponents) -> String {
        if let date = timestampAsLocalDate(comps) {
            return formatterISO8601.stringFromDate(date)
        } else {
            return "Invalid"
        }
    }
    
    public static func timestampStrFromDate(date: NSDate) -> String {
        return formatterISO8601.stringFromDate(date)
    }
    
    
    static func nextMidnightForDateComponents(comps: NSDateComponents) -> NSDateComponents {
        // Used to find the next midnight for the given date comps, for compatibility with decocare/nightscout.
        // The thinking is to represent the time the entry was recorded (which is midnight at the end of the day)
        
        var rval: NSDateComponents
        
        if let date = comps.date, cal = comps.calendar {
            if let nextDate = cal.dateByAddingUnit(.Day, value: 1, toDate: date, options: []) {
                let unitFlags: NSCalendarUnit = [.Second, .Minute, .Hour, .Day, .Month, .Year]
                rval = cal.components(unitFlags, fromDate: nextDate)
                rval.calendar = cal
                rval.timeZone = comps.timeZone
            }
            else {
                rval = comps
            }
        } else {
            rval = comps
        }
        return rval
    }
    
}
