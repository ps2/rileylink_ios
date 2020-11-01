//
//  BLEFirmwareVersion.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

public struct BLEFirmwareVersion {
    
    enum Firmware: String {
        case bleRFSpy = "ble_rfspy"
        case nrfRileyLink = "nrf52_rileylink"
    }

    let firmware: Firmware
    let components: [Int]
    let versionString: String

    init?(versionString: String) {
        let components = versionString.split(separator: " ")
        
        guard let firmware = Firmware.init(rawValue: String(components[0])),
              let versionIndex = versionString.index(versionString.startIndex, offsetBy: firmware.rawValue.count + 1, limitedBy: versionString.endIndex)
        else {
            return nil
        }
        
        self.init(
            firmware: firmware,
            components: versionString[versionIndex...].split(separator: ".").compactMap({ Int($0) }),
            versionString: versionString
        )
    }

    init(firmware: Firmware, components: [Int], versionString: String) {
        self.firmware = firmware
        self.components = components
        self.versionString = versionString
    }
}

extension BLEFirmwareVersion: CustomStringConvertible {
    public var description: String {
        return versionString
    }
}


extension BLEFirmwareVersion: Equatable {
    public static func ==(lhs: BLEFirmwareVersion, rhs: BLEFirmwareVersion) -> Bool {
        return lhs.components == rhs.components
    }
}


extension BLEFirmwareVersion {
    var responseType: PeripheralManager.ResponseType {
        switch firmware {
        case .bleRFSpy:
            guard let major = components.first, major >= 2 else {
                return .buffered
            }

            return .single
        case .nrfRileyLink:
            return .single
        }
    }
}
