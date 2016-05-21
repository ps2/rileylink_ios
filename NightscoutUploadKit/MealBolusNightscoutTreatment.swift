//
//  MealBolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class MealBolusNightscoutTreatment: NightscoutTreatment {
    
    let glucose: Int
    let glucoseType: GlucoseType
    let units: Units
    let carbs: Int
    let insulin: Double
    
    init(timestamp: NSDate, enteredBy: String, glucose: Int, glucoseType: GlucoseType, units: Units, carbs: Int, insulin: Double) {
        self.glucose = glucose
        self.glucoseType = glucoseType
        self.units = units
        self.insulin = insulin
        self.carbs = carbs
        super.init(timestamp: timestamp, enteredBy: enteredBy)
    }
    
    override public var dictionaryRepresentation: [String: AnyObject] {
        var rval = super.dictionaryRepresentation
        rval["eventType"] = "Meal Bolus"
        rval["glucose"] = glucose
        rval["glucoseType"] = glucoseType.rawValue
        rval["units"] = units.rawValue
        return rval
    }
    
}
