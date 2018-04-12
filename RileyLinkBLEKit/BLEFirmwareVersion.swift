//
//  BLEFirmwareVersion.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

public struct BLEFirmwareVersion {
    private static let prefix = "ble_rfspy "

    let components: [Int]

    let versionString: String

    init?(versionString: String) {
        guard
            versionString.hasPrefix(BLEFirmwareVersion.prefix),
            let versionIndex = versionString.index(versionString.startIndex, offsetBy: BLEFirmwareVersion.prefix.count, limitedBy: versionString.endIndex)
        else {
            return nil
        }

        self.versionString = versionString
        components = versionString[versionIndex...].split(separator: ".").compactMap({ Int($0) })
    }
}


extension BLEFirmwareVersion: CustomStringConvertible {
    public var description: String {
        return versionString
    }
}


extension BLEFirmwareVersion {
    var responseType: PeripheralManager.ResponseType {
        guard let major = components.first, major >= 2 else {
            return .buffered
        }

        return .single
    }
}
