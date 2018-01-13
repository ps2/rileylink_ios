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
    case invalidInput(String)
    case invalidResponse(Data)
    case timeout
    case unknownCharacteristic
    case writeSizeLimitExceeded(maxLength: Int)
}


extension PeripheralManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cbPeripheralError(let error):
            return error.localizedDescription
        case .notReady:
            return NSLocalizedString("Peripheral isnʼt connected", comment: "Not ready error description")
        case .invalidInput(let input):
            return String(format: NSLocalizedString("Input %@ is invalid", comment: "Invalid input error description (1: input)"), input)
        case .invalidResponse(let response):
            return String(format: NSLocalizedString("Response %@ is invalid", comment: "Invalid response error description (1: response)"), response.hexadecimalString)
        case .timeout:
            return NSLocalizedString("Peripheral did not respond in time", comment: "Timeout error description")
        case .unknownCharacteristic:
            return NSLocalizedString("Unknown characteristic", comment: "Error description")
        case .writeSizeLimitExceeded(let maxLength):
            return String(format: NSLocalizedString("Data exceededs maximum size of %@ bytes", comment: "Write size limit exceeded error description (1: size limit)"), NumberFormatter.localizedString(from: NSNumber(value: maxLength), number: .none))
        }
    }

    var failureReason: String? {
        switch self {
        case .cbPeripheralError(let error as NSError):
            return error.localizedFailureReason
        default:
            return errorDescription
        }
    }
}
