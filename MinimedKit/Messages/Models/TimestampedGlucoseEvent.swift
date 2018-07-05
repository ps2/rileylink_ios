//
//  TimestampedGlucoseEvent.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/19/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TimestampedGlucoseEvent {
    public let glucoseEvent: GlucoseEvent
    public let date: Date
    
    public func isMutable(atDate date: Date = Date()) -> Bool {
        return false
    }
    
    public init(glucoseEvent: GlucoseEvent, date: Date) {
        self.glucoseEvent = glucoseEvent
        self.date = date
    }
}


extension TimestampedGlucoseEvent: DictionaryRepresentable {
    public var dictionaryRepresentation: [String: Any] {
        var dict = glucoseEvent.dictionaryRepresentation
        
        dict["timestamp"] = DateFormatter.ISO8601DateFormatter().string(from: date)
        
        return dict
    }
}
