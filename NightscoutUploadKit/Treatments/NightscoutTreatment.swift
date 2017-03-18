//
//  NightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import MinimedKit

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


    init(timestamp: Date, enteredBy: String, notes: String? = nil, id: String? = nil) {
        self.timestamp = timestamp
        self.enteredBy = enteredBy
        self.id = id
        self.notes = notes
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
        return rval
    }
}
