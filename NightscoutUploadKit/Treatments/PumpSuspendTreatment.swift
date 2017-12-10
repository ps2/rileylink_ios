//
//  PumpSuspendTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/27/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class PumpSuspendTreatment: NightscoutTreatment {

    public init(timestamp: Date, enteredBy: String) {
        super.init(timestamp: timestamp, enteredBy: enteredBy, eventType: "Suspend Pump")
    }

}
