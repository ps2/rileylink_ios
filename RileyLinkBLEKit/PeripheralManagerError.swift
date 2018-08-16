//
//  PeripheralManagerError.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import CoreBluetooth


enum PeripheralManagerError: Error {
    case cbPeripheralError(Error)
    case notReady
    case timeout
    case unknownCharacteristic
}


extension PeripheralManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cbPeripheralError(let error):
            return error.localizedDescription
        case .notReady:
            return LocalizedString("Peripheral isnʼt connected", comment: "Not ready error description")
        case .timeout:
            return LocalizedString("Peripheral did not respond in time", comment: "Timeout error description")
        case .unknownCharacteristic:
            return LocalizedString("Unknown characteristic", comment: "Error description")
        }
    }

    var failureReason: String? {
        switch self {
        case .cbPeripheralError(let error as NSError):
            return error.localizedFailureReason
        case .unknownCharacteristic:
            return LocalizedString("The RileyLink was temporarily disconnected", comment: "Failure reason: unknown peripheral characteristic")
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cbPeripheralError(let error as NSError):
            return error.localizedRecoverySuggestion
        case .unknownCharacteristic:
            return LocalizedString("Make sure the device is nearby, and the issue should resolve automatically", comment: "Recovery suggestion for unknown peripheral characteristic")
        default:
            return nil
        }
    }
}
