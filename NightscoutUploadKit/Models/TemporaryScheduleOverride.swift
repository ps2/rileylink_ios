//
//  TemporaryScheduleOverride.swift
//  NightscoutUploadKit
//
//  Created by Pete Schwamb on 4/21/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TemporaryScheduleOverride {
    typealias RawValue = [String: Any]

    let targetRange: ClosedRange<Double>?
    let insulinNeedsScaleFactor: Double?
    let symbol: String?
    let duration: TimeInterval
    let name: String?

    public init(duration: TimeInterval, targetRange: ClosedRange<Double>?, insulinNeedsScaleFactor: Double?, symbol: String?, name: String?) {
        self.targetRange = targetRange
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.symbol = symbol
        self.duration = duration
        self.name = name
    }

    public var dictionaryRepresentation: [String: Any] {
        var rval: [String: Any] = [
            "duration": duration,
        ]

        if let symbol = symbol {
            rval["symbol"] = symbol
        }

        if let targetRange = targetRange {
            rval["targetRange"] = [targetRange.lowerBound, targetRange.upperBound]
        }

        if let insulinNeedsScaleFactor = insulinNeedsScaleFactor {
            rval["insulinNeedsScaleFactor"] = insulinNeedsScaleFactor
        }
        
        if let name = name {
            rval["name"] = name
        }
        
        return rval
    }
    
    init?(rawValue: RawValue) {
        guard let duration = rawValue["duration"] as? TimeInterval else {
            return nil
        }
        
        if let targetRangeRaw = rawValue["targetRange"] as? [Double], targetRangeRaw.count == 2 {
            targetRange = ClosedRange(uncheckedBounds: (lower: targetRangeRaw[0], upper: targetRangeRaw[1]))
        } else {
            targetRange = nil
        }
        insulinNeedsScaleFactor = rawValue["insulinNeedsScaleFactor"] as? Double
        symbol = rawValue["symbol"] as? String
        self.duration = duration
        name = rawValue["name"] as? String
    }
}

