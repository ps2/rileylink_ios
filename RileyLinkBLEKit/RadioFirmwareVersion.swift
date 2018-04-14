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
        components = versionString[versionIndex...].split(separator: ".").compactMap({ Int($0) })
    }

    private init(components: [Int]) {
        versionString = "Unknown"
        self.components = components
    }

    static var unknown: RadioFirmwareVersion {
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
    
    private var atLeastV2: Bool {
        guard let major = components.first, major >= 2 else {
            return false
        }
        return true
    }
    
    var supportsPreambleExtension: Bool {
        return atLeastV2
    }
    
    var supportsSoftwareEncoding: Bool {
        return atLeastV2
    }
    
    var supportsResetRadioConfig: Bool {
        return atLeastV2
    }

    var supports16BitPacketDelay: Bool {
        return atLeastV2
    }
    
    var needsExtraByteForUpdateRegisterCommand: Bool {
        return !atLeastV2
    }

}

