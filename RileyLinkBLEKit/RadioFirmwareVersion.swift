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

    private init(components: [Int]) {
        versionString = "Unknown"
        self.components = components
    }

    public static var unknown: RadioFirmwareVersion {
        return self.init(components: [1])
    }
}


extension RadioFirmwareVersion: CustomStringConvertible {
    public var description: String {
        return versionString
    }
}

// Version 2 changes
extension RadioFirmwareVersion {
    var supportsPreambleExtension: Bool {
        guard let major = components.first, major >= 2 else {
            return false
        }
        return true
    }
    
    var supportsSoftwareEncoding: Bool {
        guard let major = components.first, major >= 2 else {
            return false
        }
        return true
    }

    var supports16SecondPacketDelay: Bool {
        guard let major = components.first, major >= 2 else {
            return false
        }
        return true
    }

}

