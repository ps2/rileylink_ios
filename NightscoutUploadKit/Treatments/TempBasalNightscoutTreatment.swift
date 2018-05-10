//
//  TempBasalNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class TempBasalNightscoutTreatment: NightscoutTreatment {
    
    public enum RateType: String {
        case Absolute = "absolute"
        case Percentage = "percentage"
    }
    
    
    let rate: Double
    let absolute: Double?
    let temp: RateType
    let duration: Int
    
    public init(timestamp: Date, enteredBy: String, temp: RateType, rate: Double, absolute: Double?, duration: Int) {
        self.rate = rate
        self.absolute = absolute
        self.temp = temp
        self.duration = duration
        
        super.init(timestamp: timestamp, enteredBy: enteredBy, eventType: "Temp Basal")
    }
    
    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["temp"] = temp.rawValue
        rval["rate"] = rate
        if let absolute = absolute {
            rval["absolute"] = absolute
        }
        rval["duration"] = duration
        return rval
    }
}
