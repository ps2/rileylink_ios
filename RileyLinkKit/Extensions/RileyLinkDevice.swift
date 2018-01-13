//
//  RileyLinkDevice.swift
//  RileyLinkKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import RileyLinkBLEKit

extension RileyLinkDevice.Status {
    public var firmwareDescription: String {
        let versions = [radioFirmwareVersion, bleFirmwareVersion].flatMap { (version: CustomStringConvertible?) -> String? in
            if let version = version {
                return String(describing: version)
            } else {
                return nil
            }
        }

        return versions.joined(separator: " / ")
    }
}
