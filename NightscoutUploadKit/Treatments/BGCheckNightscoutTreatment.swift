//
//  BGCheckNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class BGCheckNightscoutTreatment: NightscoutTreatment {
    
    let glucose: Int
    let glucoseType: GlucoseType
    let units: Units
    
    init(timestamp: Date, enteredBy: String, glucose: Int, glucoseType: GlucoseType, units: Units, notes: String? = nil) {
        self.glucose = glucose
        self.glucoseType = glucoseType
        self.units = units
        super.init(timestamp: timestamp, enteredBy: enteredBy, notes: notes)
    }
    
    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["eventType"] = "BG Check"
        rval["glucose"] = glucose
        rval["glucoseType"] = glucoseType.rawValue
        rval["units"] = units.rawValue
        return rval
    }
}
