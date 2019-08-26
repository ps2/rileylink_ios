//
//  NightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol DictionaryRepresentable {
    var dictionaryRepresentation: [String: Any] {
        get
    }
}

public class NightscoutTreatment: DictionaryRepresentable {
    
    public enum GlucoseType: String {
        case Meter
        case Sensor
    }
    
    public enum Units: String {
        case MMOLL = "mmol/L"
        case MGDL = "mg/dL"
    }
    
    let timestamp: Date
    let enteredBy: String
    let notes: String?
    let id: String?
    let eventType: String?


    public init(timestamp: Date, enteredBy: String, notes: String? = nil, id: String? = nil, eventType: String? = nil) {
        self.timestamp = timestamp
        self.enteredBy = enteredBy
        self.id = id
        self.notes = notes
        self.eventType = eventType
    }
    
    public var dictionaryRepresentation: [String: Any] {
        var rval = [
            "created_at": TimeFormat.timestampStrFromDate(timestamp),
            "timestamp": TimeFormat.timestampStrFromDate(timestamp),
            "enteredBy": enteredBy,
        ]
        if let id = id {
            rval["_id"] = id
        }
        if let notes = notes {
            rval["notes"] = notes
        }
        if let eventType = eventType {
            rval["eventType"] = eventType
        }
        return rval
    }
}
