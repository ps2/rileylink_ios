//
//  PredictedBG.swift
//  RileyLink
//
//  Created by Pete Schwamb on 8/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import HealthKit

public struct PredictedBG {
    let values: [Int]
    let cob: [Int]?
    let iob: [Int]?

    public init(values: [HKQuantity], cob: [HKQuantity]? = nil, iob: [HKQuantity]? = nil) {
        // BG values in nightscout are in mg/dL.
        let unit = HKUnit.milligramsPerDeciliterUnit()
        self.values = values.map { Int(round($0.doubleValueForUnit(unit))) }
        self.cob = cob?.map { Int(round($0.doubleValueForUnit(unit))) }
        self.iob = iob?.map { Int(round($0.doubleValueForUnit(unit))) }
    }

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["values"] = values

        if let cob = cob {
            rval["COB"] = cob
        }

        if let iob = iob {
            rval["IOB"] = iob
        }

        return rval
    }
}
