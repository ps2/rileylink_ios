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
    case timeout([PeripheralManager.CommandCondition])
    case emptyValue
    case unknownCharacteristic
}


extension PeripheralManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cbPeripheralError(let error):
            return error.localizedDescription
        case .notReady:
            return LocalizedString("RileyLink is not connected", comment: "PeripheralManagerError.notReady error description")
        case .timeout:
            return LocalizedString("RileyLink did not respond in time", comment: "PeripheralManagerError.timeout error description")
        case .emptyValue:
            return LocalizedString("Characteristic value was empty", comment: "PeripheralManagerError.emptyValue error description")
        case .unknownCharacteristic:
            return LocalizedString("Unknown characteristic", comment: "PeripheralManagerError.unknownCharacteristic error description")
        }
    }

    public var failureReason: String? {
        switch self {
        case .cbPeripheralError(let error as NSError):
            return error.localizedFailureReason
        case .unknownCharacteristic:
            return LocalizedString("The RileyLink was temporarily disconnected", comment: "Failure reason: unknown peripheral characteristic")
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
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
