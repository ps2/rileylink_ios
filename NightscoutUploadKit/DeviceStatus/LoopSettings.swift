//
//  LoopSettings.swift
//  NightscoutUploadKit
//
//  Created by Pete Schwamb on 4/21/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//
import Foundation

public struct LoopSettings {
    typealias RawValue = [String: Any]
    
    let dosingEnabled: Bool
    let overridePresets: [TemporaryScheduleOverride]
    let scheduleOverride: TemporaryScheduleOverride?
    let minimumBGGuard: Double?
    let preMealTargetRange: ClosedRange<Double>?
    let maximumBasalRatePerHour: Double?
    let maximumBolus: Double?
    let deviceToken: Data?
    let bundleIdentifier: String?

    public init(dosingEnabled: Bool, overridePresets: [TemporaryScheduleOverride], scheduleOverride: TemporaryScheduleOverride?, minimumBGGuard: Double?, preMealTargetRange: ClosedRange<Double>?, maximumBasalRatePerHour: Double?, maximumBolus: Double?,
                deviceToken: Data?, bundleIdentifier: String?) {
        self.dosingEnabled = dosingEnabled
        self.overridePresets = overridePresets
        self.scheduleOverride = scheduleOverride
        self.minimumBGGuard = minimumBGGuard
        self.preMealTargetRange = preMealTargetRange
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.deviceToken = deviceToken
        self.bundleIdentifier = bundleIdentifier
    }

    public var dictionaryRepresentation: [String: Any] {

        var rval: [String: Any] = [
            "dosingEnabled": dosingEnabled,
            "overridePresets": overridePresets.map { $0.dictionaryRepresentation },
        ]

        if let minimumBGGuard = minimumBGGuard {
            rval["minimumBGGuard"] = minimumBGGuard
        }

        if let scheduleOverride = scheduleOverride {
            rval["scheduleOverride"] = scheduleOverride.dictionaryRepresentation
        }

        if let preMealTargetRange = preMealTargetRange {
            rval["preMealTargetRange"] = [preMealTargetRange.lowerBound, preMealTargetRange.upperBound]
        }

        if let maximumBasalRatePerHour = maximumBasalRatePerHour {
            rval["maximumBasalRatePerHour"] = maximumBasalRatePerHour
        }

        if let maximumBolus = maximumBolus {
            rval["maximumBolus"] = maximumBolus
        }

        if let deviceToken = deviceToken {
            rval["deviceToken"] = deviceToken.hexadecimalString
        }

        if let bundleIdentifier = bundleIdentifier {
            rval["bundleIdentifier"] = bundleIdentifier
        }

        return rval
    }

    init?(rawValue: RawValue) {
         guard
             let dosingEnabled = rawValue["dosingEnabled"] as? Bool,
             let overridePresetsRaw = rawValue["overridePresets"] as? [TemporaryScheduleOverride.RawValue]
         else {
             return nil
         }

         self.dosingEnabled = dosingEnabled
         self.overridePresets = overridePresetsRaw.compactMap { TemporaryScheduleOverride(rawValue: $0) }

         if let scheduleOverrideRaw = rawValue["scheduleOverride"] as? TemporaryScheduleOverride.RawValue {
             scheduleOverride = TemporaryScheduleOverride(rawValue: scheduleOverrideRaw)
         } else {
             scheduleOverride = nil
         }

         minimumBGGuard = rawValue["minimumBGGuard"] as? Double

         if let preMealTargetRangeRaw = rawValue["preMealTargetRange"] as? [Double], preMealTargetRangeRaw.count == 2 {
             preMealTargetRange = ClosedRange(uncheckedBounds: (lower: preMealTargetRangeRaw[0], upper: preMealTargetRangeRaw[1]))
         } else {
             preMealTargetRange = nil
         }

         maximumBasalRatePerHour = rawValue["maximumBasalRatePerHour"] as? Double

         maximumBolus = rawValue["maximumBolus"] as? Double

         if let deviceTokenHex = rawValue["deviceToken"] as? String, let deviceToken = Data(hexadecimalString: deviceTokenHex) {
             self.deviceToken = deviceToken
         } else {
             self.deviceToken = nil
         }

         bundleIdentifier = rawValue["bundleIdentifier"] as? String
     }
}
