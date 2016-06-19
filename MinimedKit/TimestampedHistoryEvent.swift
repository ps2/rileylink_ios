//
//  TimestampedPumpEvent.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 6/15/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation


// Boxes a TimestampedPumpEvent, storing its reconciled date components
public struct TimestampedHistoryEvent {
    public let pumpEvent: PumpEvent
    public let date: NSDate

    public func isMutable(atDate date: NSDate = NSDate()) -> Bool {
        switch pumpEvent {
        case let bolus as BolusNormalPumpEvent:
            // Square boluses
            let deliveryFinishDate = self.date.dateByAddingTimeInterval(bolus.deliveryTime)
            return deliveryFinishDate.compare(date) == .OrderedDescending
        default:
            return false
        }
    }

    public init(pumpEvent: PumpEvent, date: NSDate) {
        self.pumpEvent = pumpEvent
        self.date = date
    }
}


extension TimestampedHistoryEvent: DictionaryRepresentable {
    public var dictionaryRepresentation: [String : AnyObject] {
        var dict = pumpEvent.dictionaryRepresentation

        dict["timestamp"] = NSDateFormatter.ISO8601DateFormatter().stringFromDate(date)

        return dict
    }
}
