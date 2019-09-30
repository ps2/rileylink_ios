//
//  OverrideTreatment.swift
//  NightscoutUploadKit
//
//  Created by Pete Schwamb on 9/28/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation

public class OverrideTreatment: NightscoutTreatment {

    let correctionRange: ClosedRange<Double>?  // mg/dL
    let insulinNeedsScaleFactor: Double?
    let duration: TimeInterval?
    let reason: String
    let remoteAddress: String?

    public init(startDate: Date, enderedBy: String, reason: String, duration: TimeInterval?, correctionRange: ClosedRange<Double>?, insulinNeedsScaleFactor: Double?, remoteAddress: String? = nil, id: String? = nil) {
        self.reason = reason
        self.duration = duration
        self.correctionRange = correctionRange
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.remoteAddress = remoteAddress
        super.init(timestamp: startDate, enteredBy: enderedBy, id: id, eventType: "Temporary Override")
    }

    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation

        rval["duration"] = duration?.minutes
        rval["reason"] = reason
        rval["insulinNeedsScaleFactor"] = insulinNeedsScaleFactor
        rval["remoteAddress"] = remoteAddress

        if let correctionRange = correctionRange {
            rval["correctionRange"] = [correctionRange.lowerBound, correctionRange.upperBound]
        }

        return rval
    }
}
