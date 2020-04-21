//
//  BolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class BolusNightscoutTreatment: NightscoutTreatment {
    
    public enum BolusType: String {
        case Normal = "normal"
        case Square = "square"
        case DualWave = "dual"
    }

    public let bolusType: BolusType
    public let amount: Double
    public let programmed: Double
    public let unabsorbed: Double?
    public let duration: TimeInterval
    public let carbs: Double?
    public let ratio: Double?

    public init(timestamp: Date, enteredBy: String, bolusType: BolusType, amount: Double, programmed: Double, unabsorbed: Double?, duration: TimeInterval, carbs: Double?, ratio: Double?, notes: String? = nil, id: String?) {
        self.bolusType = bolusType
        self.amount = amount
        self.programmed = programmed
        self.unabsorbed = unabsorbed
        self.duration = duration
        self.carbs = carbs
        self.ratio = ratio
        // Commenting out usage of surrogate ID until Nightscout supports it.
        super.init(timestamp: timestamp, enteredBy: enteredBy, notes: notes, /* id: id, */
            eventType: ((carbs ?? 0) > 0) ? .mealBolus : .correctionBolus)

    }
    
    required public init?(_ entry: [String : Any]) {
        guard
            let bolusTypeRaw = entry["type"] as? String,
            let bolusType = BolusType(rawValue: bolusTypeRaw),
            let amount = entry["insulin"] as? Double,
            let programmed = entry["programmed"] as? Double,
            let durationMinutes = entry["duration"] as? Double
        else {
            return nil
        }
        
        self.bolusType = bolusType
        self.amount = amount
        self.programmed = programmed
        self.duration = TimeInterval(minutes: durationMinutes)
        
        self.carbs = entry["carbs"] as? Double
        self.ratio = entry["ratio"] as? Double
        
        self.unabsorbed = entry["unabsorbed"] as? Double
        
        super.init(entry)
    }
    
    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        if let carbs = carbs, carbs > 0 {
            rval["carbs"] = carbs
        }
        
        if let ratio = ratio {
            rval["ratio"] = ratio
        }
        rval["type"] = bolusType.rawValue
        rval["insulin"] = amount
        rval["programmed"] = programmed
        rval["unabsorbed"] = unabsorbed
        rval["duration"] = duration.minutes
        return rval
    }
}
