//
//  RadioFirmwareVersion.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

public struct RadioFirmwareVersion {
    private static let prefix = "subg_rfspy "

    let components: [Int]

    let versionString: String

    init?(versionString: String) {
        guard versionString.hasPrefix(RadioFirmwareVersion.prefix),
            let versionIndex = versionString.index(versionString.startIndex, offsetBy: RadioFirmwareVersion.prefix.count, limitedBy: versionString.endIndex)
        else {
            return nil
        }

        self.versionString = versionString
        components = versionString[versionIndex...].split(separator: ".").flatMap({ Int($0) })
    }
}


extension RadioFirmwareVersion: CustomStringConvertible {
    public var description: String {
        return versionString
    }
}
