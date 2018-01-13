//
//  DeviceState.swift
//  RileyLinkKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//


public struct DeviceState {
    public var lastTuned: Date?

    public var lastValidFrequency: Measurement<UnitFrequency>?

    public init(lastTuned: Date? = nil, lastValidFrequency: Measurement<UnitFrequency>? = nil) {
        self.lastTuned = lastTuned
        self.lastValidFrequency = lastValidFrequency
    }
}


extension DeviceState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## DeviceState",
            "lastValidFrequency: \(String(describing: lastValidFrequency))",
            "lastTuned: \(String(describing: lastTuned))",
        ].joined(separator: "\n")
    }
}
