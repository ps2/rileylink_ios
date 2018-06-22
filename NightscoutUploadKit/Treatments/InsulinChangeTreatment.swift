//
//  InsulinChangeTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/27/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class InsulinChangeTreatment: NightscoutTreatment {
    public init(timestamp: Date, enteredBy: String, notes: String? = nil) {
        super.init(timestamp: timestamp, enteredBy: enteredBy, notes: notes, eventType: "Insulin Change")
    }
}
