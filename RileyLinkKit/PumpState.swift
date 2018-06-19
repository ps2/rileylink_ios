//
//  PumpState.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit


public struct PumpState: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    public var timeZone: TimeZone
    
    public var pumpModel: PumpModel?
    
    public var awakeUntil: Date?
    
    var isAwake: Bool {
        if let awakeUntil = awakeUntil {
            return awakeUntil.timeIntervalSinceNow > 0
        }

        return false
    }
    
    var lastWakeAttempt: Date?

    public init() {
        self.timeZone = .currentFixed
    }

    public init?(rawValue: RawValue) {
        guard
            let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
        else {
            return nil
        }

        self.timeZone = timeZone

        if let pumpModelNumber = rawValue["pumpModel"] as? PumpModel.RawValue {
            pumpModel = PumpModel(rawValue: pumpModelNumber)
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "timeZone": timeZone.secondsFromGMT(),
        ]

        if let pumpModel = pumpModel {
            rawValue["pumpModel"] = pumpModel.rawValue
        }

        return rawValue
    }
}


extension PumpState: CustomDebugStringConvertible {
    public var debugDescription: String {

        return [
            "## PumpState",
            "timeZone: \(timeZone)",
            "pumpModel: \(pumpModel?.rawValue ?? "")",
            "awakeUntil: \(awakeUntil ?? .distantPast)",
            "lastWakeAttempt: \(String(describing: lastWakeAttempt))"
        ].joined(separator: "\n")
    }
}
