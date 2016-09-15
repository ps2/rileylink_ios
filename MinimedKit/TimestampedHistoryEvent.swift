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
    public let date: Date

    public func isMutable(atDate date: Date = Date()) -> Bool {
        switch pumpEvent {
        case let bolus as BolusNormalPumpEvent:
            // Square boluses
            let deliveryFinishDate = self.date.addingTimeInterval(bolus.deliveryTime)
            return deliveryFinishDate.compare(date) == .orderedDescending
        default:
            return false
        }
    }

    public init(pumpEvent: PumpEvent, date: Date) {
        self.pumpEvent = pumpEvent
        self.date = date
    }
}


extension TimestampedHistoryEvent: DictionaryRepresentable {
    public var dictionaryRepresentation: [String : Any] {
        var dict = pumpEvent.dictionaryRepresentation

        dict["timestamp"] = DateFormatter.ISO8601DateFormatter().string(from: date)

        return dict
    }
}
