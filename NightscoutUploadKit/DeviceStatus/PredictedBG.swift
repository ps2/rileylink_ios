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
    let values: [Double]
    let cob: [Double]?
    let iob: [Double]?

    public init(values: [HKQuantity], cob: [HKQuantity]? = nil, iob: [HKQuantity]? = nil) {
        // All nightscout data is in mg/dL.
        let unit = HKUnit.milligramsPerDeciliterUnit()
        self.values = values.map { $0.doubleValueForUnit(unit) }
        self.cob = cob?.map { $0.doubleValueForUnit(unit) }
        self.iob = iob?.map { $0.doubleValueForUnit(unit) }
    }

    public init(values: [Double], cob: [Double]? = nil, iob: [Double]? = nil) {
        self.values = values
        self.cob = cob
        self.iob = iob
    }

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["values"] = values

        if let cob = cob {
            rval["cob"] = cob
        }

        if let iob = iob {
            rval["iob"] = iob
        }

        return rval
    }
}
