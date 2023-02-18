//
//  OverrideStatus.swift
//  NightscoutUploadKit
//
//  Created by Kenneth Stack on 5/6/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import HealthKit

public struct OverrideStatus {
    
    typealias RawValue = [String: Any]
    
    public let name: String?
    public let timestamp: Date
    public let active: Bool
    public let currentCorrectionRange: CorrectionRange?
    public let duration: TimeInterval?
    public let multiplier: Double?
    
    
    public init(name: String? = nil, timestamp: Date, active: Bool, currentCorrectionRange: CorrectionRange? = nil, duration: TimeInterval? = nil, multiplier: Double? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.active = active
        self.currentCorrectionRange = currentCorrectionRange
        self.duration = duration
        self.multiplier = multiplier
    }
    
    public var dictionaryRepresentation: [String: Any] {
        var rval = [String: Any]()
        
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["active"] = active
        
        if let name = name {
            rval["name"] = name
        }
        
        if let currentCorrectionRange = currentCorrectionRange {
            rval["currentCorrectionRange"] = currentCorrectionRange.dictionaryRepresentation
        }
        
        if let duration = duration {
            rval["duration"] = duration
        }
        
        if let multiplier = multiplier {
            rval["multiplier"] = multiplier
        }
        
        return rval
    }
    
    init?(rawValue: RawValue) {
        
        guard
            let timestampStr = rawValue["timestamp"] as? String,
            let timestamp = TimeFormat.dateFromTimestamp(timestampStr),
            let active = rawValue["active"] as? Bool
        else {
            return nil
        }

        self.timestamp = timestamp
        self.active = active
        self.name = rawValue["name"] as? String

        if let currentCorrectionRangeRaw = rawValue["currentCorrectionRange"] as? CorrectionRange.RawValue {
            self.currentCorrectionRange = CorrectionRange(rawValue: currentCorrectionRangeRaw)
        } else {
            self.currentCorrectionRange = nil
        }

        duration = rawValue["duration"] as? TimeInterval
        multiplier = rawValue["multiplier"] as? Double
    }
}
