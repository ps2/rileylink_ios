//
//  RileyLinkPumpManagerState.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import RileyLinkBLEKit


public struct RileyLinkPumpManagerState: RawRepresentable {
    public typealias RawValue = PumpManager.RawStateValue

    public var rileyLinkConnectionManagerState: RileyLinkConnectionManager.RawStateValue?

    public init(rileyLinkConnectionManagerState: RileyLinkConnectionManager.RawStateValue?) {
        self.rileyLinkConnectionManagerState = rileyLinkConnectionManagerState
    }

    public init?(rawValue: RawValue) {
        guard let rileyLinkConnectionManagerState = rawValue["rileyLinkConnectionManagerState"] as? RileyLinkConnectionManager.RawStateValue else {
            return nil
        }

        self.init(rileyLinkConnectionManagerState: rileyLinkConnectionManagerState)
    }

    public var rawValue: RawValue {
        var value = [String : Any]()
        if let connectionManagerState = rileyLinkConnectionManagerState {
            value["rileyLinkConnectionManagerState"] = connectionManagerState
        }
        return value
    }
}


extension RileyLinkPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## RileyLinkPumpManagerState",
            "rileyLinkConnectionManagerState: \(String(describing: rileyLinkConnectionManagerState))",
        ].joined(separator: "\n")
    }
}
