//
//  NSDateComponents.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/13/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension NSDateComponents {
    convenience init(mySentryBytes: [UInt8]) {
        self.init()

        hour   = Int(mySentryBytes[0])
        minute = Int(mySentryBytes[1])
        second = Int(mySentryBytes[2])
        year   = Int(mySentryBytes[3]) + 2000
        month  = Int(mySentryBytes[4])
        day    = Int(mySentryBytes[5])

        calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
    }

    convenience init(pumpEventData: NSData, offset: Int, length: Int = 5) {
        self.init(pumpEventBytes: pumpEventData[offset..<offset + length])
    }

    convenience init(pumpEventBytes: [UInt8]) {
        self.init()

        if pumpEventBytes.count == 5 {
            second = Int(pumpEventBytes[0] & 0b00111111)
            minute = Int(pumpEventBytes[1] & 0b00111111)
            hour   = Int(pumpEventBytes[2] & 0b00011111)
            day    = Int(pumpEventBytes[3] & 0b00011111)
            month = Int((pumpEventBytes[0] & 0b11000000) >> 4 +
                        (pumpEventBytes[1] & 0b11000000) >> 6)
            year   = Int(pumpEventBytes[4] & 0b01111111) + 2000
        } else {
            day    = Int(pumpEventBytes[0] & 0b00011111)
            month = Int((pumpEventBytes[0] & 0b11100000) >> 4 +
                        (pumpEventBytes[1] & 0b10000000) >> 7)
            year   = Int(pumpEventBytes[1] & 0b01111111) + 2000
        }

        calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
    }
}
