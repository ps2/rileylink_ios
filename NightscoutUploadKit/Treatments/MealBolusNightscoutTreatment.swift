//
//  MealBolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class MealBolusNightscoutTreatment: NightscoutTreatment {
    
    let carbs: Int
    let insulin: Double?
    let glucose: Int?
    let units: Units? // of glucose entry
    let glucoseType: GlucoseType?

    public init(timestamp: Date, enteredBy: String, carbs: Int, insulin: Double? = nil, glucose: Int? = nil, glucoseType: GlucoseType? = nil, units: Units? = nil) {
        self.glucose = glucose
        self.glucoseType = glucoseType
        self.units = units
        self.insulin = insulin
        self.carbs = carbs
        super.init(timestamp: timestamp, enteredBy: enteredBy)
    }
    
    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["eventType"] = "Meal Bolus"
        if let glucose = glucose {
            rval["glucose"] = glucose
            rval["glucoseType"] = glucoseType?.rawValue
            rval["units"] = units?.rawValue
        }
        rval["carbs"] = carbs
        rval["insulin"] = insulin
        return rval
    }
}
