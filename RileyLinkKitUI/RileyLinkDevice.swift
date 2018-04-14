//
//  RileyLinkDevice.swift
//  RileyLinkKitUI
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import RileyLinkBLEKit


/// Provide a notification contract that clients can use to inform RileyLink UI of changes to DeviceState
extension RileyLinkDevice {
    public static let notificationDeviceStateKey = "com.rileylink.RileyLinkKit.RileyLinkDevice.DeviceState"
}

extension Notification.Name {
    public static let DeviceStateDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.DeviceStateDidChange")
}
