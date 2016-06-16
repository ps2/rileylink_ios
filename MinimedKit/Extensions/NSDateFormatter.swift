//
//  NSDateFormatter.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 6/15/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation


extension NSDateFormatter {
    class func ISO8601DateFormatter() -> Self {
        let formatter = self.init()
        formatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierISO8601)
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssX"

        return formatter
    }
}
