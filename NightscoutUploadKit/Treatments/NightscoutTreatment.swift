//
//  NightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import MinimedKit

public class NightscoutTreatment : DictionaryRepresentable {
    
    enum GlucoseType: String {
        case Meter
        case Sensor
    }
    
    public enum Units: String {
        case MMOLL = "mmol/L"
        case MGDL = "mg/dL"
    }
    
    let timestamp: Date
    let enteredBy: String
    
    init(timestamp: Date, enteredBy: String) {
        self.timestamp = timestamp
        self.enteredBy = enteredBy
    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "created_at": TimeFormat.timestampStrFromDate(timestamp),
            "timestamp": TimeFormat.timestampStrFromDate(timestamp),
            "enteredBy": enteredBy,
        ]
    }
}
