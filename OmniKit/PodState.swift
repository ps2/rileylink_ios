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
    public let isActive: Bool
    let nonceState: NonceState
    
    public init(address: UInt32 = 0x1f0a000, nonceState: NonceState = NonceState(), isActive: Bool = false) {
        self.address = address
        self.nonceState = nonceState
        self.isActive = isActive
    }
        
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let address = rawValue["address"] as? UInt32,
            let nonceStateRaw = rawValue["nonceState"] as? NonceState.RawValue,
            let isActive = rawValue["isActive"] as? Bool,
            let nonceState = NonceState(rawValue: nonceStateRaw)
            else {
                return nil
            }
        
        self.address = address
        self.nonceState = nonceState
        self.isActive = isActive
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "address": address,
            "nonceState": nonceState.rawValue,
            "isActive": isActive
            ]
        
        return rawValue
    }

}

