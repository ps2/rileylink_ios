//
//  BolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class BolusNightscoutTreatment: NightscoutTreatment {
    
    enum BolusType: String {
        case Normal = "normal"
        case Square = "square"
        case DualWave = "dual"
    }
    
    let bolusType: BolusType
    let amount: Double
    let programmed: Double
    let unabsorbed: Double
    let duration: Int
    let carbs: Int
    let ratio: Double
    
    init(timestamp: NSDate, enteredBy: String, bolusType: BolusType, amount: Double, programmed: Double, unabsorbed: Double, duration: Int, carbs: Int, ratio: Double) {
        self.bolusType = bolusType
        self.amount = amount
        self.programmed = programmed
        self.unabsorbed = unabsorbed
        self.duration = duration
        self.carbs = carbs
        self.ratio = ratio
        super.init(timestamp: timestamp, enteredBy: enteredBy)
    }
    
    override public var dictionaryRepresentation: [String: AnyObject] {
        var rval = super.dictionaryRepresentation
        if carbs > 0 {
            rval["eventType"] = "Meal Bolus"
            rval["carbs"] = carbs
            rval["ratio"] = ratio
        } else {
            rval["eventType"] = "Correction Bolus"
        }
        rval["type"] = bolusType.rawValue
        rval["insulin"] = amount
        rval["programmed"] = programmed
        rval["unabsorbed"] = unabsorbed
        rval["duration"] = duration
        return rval
    }
}
