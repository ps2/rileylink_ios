//
//  PumpOps.swift
//  RileyLinkKitUI
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import RileyLinkKit


/// Provide a notification contract that clients can use to inform RileyLink UI of changes to PumpOps.PumpState
extension PumpOps {
    public static let notificationPumpStateKey = "com.rileylink.RileyLinkKit.PumpOps.PumpState"
}

extension Notification.Name {
    public static let PumpOpsStateDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.PumpOpsStateDidChange")
}
