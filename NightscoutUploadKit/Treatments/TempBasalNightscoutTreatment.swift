//
//  TempBasalNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class TempBasalNightscoutTreatment: NightscoutTreatment {
    
    enum RateType: String {
        case Absolute = "absolute"
        case Percentage = "percentage"
    }
    
    
    let rate: Double
    let percent: Double
    let absolute: Double?
    let temp: RateType
    let duration: Int
    
    init(timestamp: Date, enteredBy: String, temp: RateType, rate: Double, percent: Double, absolute: Double?, duration: Int) {
        self.rate = rate
        self.percent = percent
        self.absolute = absolute
        self.temp = temp
        self.duration = duration
        
        super.init(timestamp: timestamp, enteredBy: enteredBy, eventType: "Temp Basal")
    }
    
    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["temp"] = temp.rawValue
        rval["rate"] = rate
        rval["percent"] = percent
        if let absolute = absolute {
            rval["absolute"] = absolute
        }
        rval["duration"] = duration
        return rval
    }
}
