//
//  RileyLinkDeviceManager.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import RileyLinkBLEKit

extension RileyLinkDeviceManager {
    public func firstConnectedDevice(_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) {
        getDevices { (devices) in
            completion(devices.firstConnected)
        }
    }
}
