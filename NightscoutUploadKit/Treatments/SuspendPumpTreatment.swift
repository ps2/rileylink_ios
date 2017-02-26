//
//  SuspendPumpTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/25/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class SuspendPumpTreatment: NightscoutTreatment {

    let suspended: Bool

    init(timestamp: Date, enteredBy: String, suspended: Bool) {
        self.suspended = suspended

        super.init(timestamp: timestamp, enteredBy: enteredBy)
    }

    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["eventType"] = "Pump Suspend"
        rval["suspended"] = suspended
        return rval
    }
}
