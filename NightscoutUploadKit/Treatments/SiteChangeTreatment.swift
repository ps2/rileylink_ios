//
//  SiteChangeTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/27/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class SiteChangeTreatment: NightscoutTreatment {
    public init(timestamp: Date, enteredBy: String, primeType: String, amount: Double, programmedAmount: Double,
                notes: String? = nil) {
        let finalNotes = notes ?? "\(primeType): \(amount) / \(programmedAmount) Units"
        super.init(timestamp: timestamp, enteredBy: enteredBy, notes: finalNotes, eventType: "Site Change")
    }
}
