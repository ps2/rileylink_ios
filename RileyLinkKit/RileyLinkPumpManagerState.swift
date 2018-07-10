//
//  RileyLinkPumpManagerState.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


public struct RileyLinkPumpManagerState: RawRepresentable, Equatable {
    public typealias RawValue = PumpManager.RawStateValue

    public var connectedPeripheralIDs: Set<String>

    public init(connectedPeripheralIDs: Set<String>) {
        self.connectedPeripheralIDs = connectedPeripheralIDs
    }

    public init?(rawValue: RawValue) {
        guard let connectedPeripheralIDs = rawValue["connectedPeripheralIDs"] as? [String] else {
            return nil
        }

        self.init(connectedPeripheralIDs: Set(connectedPeripheralIDs))
    }

    public var rawValue: RawValue {
        return [
            "connectedPeripheralIDs": Array(connectedPeripheralIDs)
        ]
    }
}


extension RileyLinkPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## RileyLinkPumpManagerState",
            "connectedPeripheralIDs: \(connectedPeripheralIDs)",
        ].joined(separator: "\n")
    }
}
