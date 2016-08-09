//
//  HKUnit.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 8/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import HealthKit


extension HKUnit {
    static func milligramsPerDeciliterUnit() -> HKUnit {
        return HKUnit.gramUnitWithMetricPrefix(.Milli).unitDividedByUnit(HKUnit.literUnitWithMetricPrefix(.Deci))
    }
}
