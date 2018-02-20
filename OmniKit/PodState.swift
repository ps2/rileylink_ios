//
//  PodState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodState: RawRepresentable {
    public typealias RawValue = [String: Any]

    public let address: UInt32
    let nonceState: NonceState
    public let isActive: Bool
    public let timeZone: TimeZone

    public static func initialPodState() -> PodState {
        return PodState(address: 0x1f0a000, nonceState: NonceState(), isActive: false, timeZone: .currentFixed)
    }

    public init(address: UInt32, nonceState: NonceState, isActive: Bool, timeZone: TimeZone) {
        self.address = address
        self.nonceState = nonceState
        self.isActive = isActive
        self.timeZone = timeZone
    }

    // RawRepresentable
    public init?(rawValue: RawValue) {

        guard
            let address = rawValue["address"] as? UInt32,
            let nonceStateRaw = rawValue["nonceState"] as? NonceState.RawValue,
            let isActive = rawValue["isActive"] as? Bool,
            let nonceState = NonceState(rawValue: nonceStateRaw),
            let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
            else {
                return nil
            }
        
        self.address = address
        self.nonceState = nonceState
        self.isActive = isActive
        self.timeZone = timeZone
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "address": address,
            "nonceState": nonceState.rawValue,
            "isActive": isActive,
            "timeZone": timeZone.secondsFromGMT()
            ]
        
        return rawValue
    }

}

