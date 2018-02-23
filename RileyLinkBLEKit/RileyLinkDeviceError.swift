//
//  RileyLinkDeviceError.swift
//  RileyLinkBLEKit
//
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//


public enum RileyLinkDeviceError: Error {
    case peripheralManagerError(LocalizedError)
    case invalidInput(String)
    case writeSizeLimitExceeded(maxLength: Int)
    case invalidResponse(Data)
    case responseTimeout
    case unsupportedCommand
}


extension RileyLinkDeviceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .peripheralManagerError(let error):
            return error.errorDescription
        case .invalidInput(let input):
            return String(format: NSLocalizedString("Input %@ is invalid", comment: "Invalid input error description (1: input)"), String(describing: input))
        case .invalidResponse(let response):
            return String(format: NSLocalizedString("Response %@ is invalid", comment: "Invalid response error description (1: response)"), String(describing: response))
        case .writeSizeLimitExceeded(let maxLength):
            return String(format: NSLocalizedString("Data exceededs maximum size of %@ bytes", comment: "Write size limit exceeded error description (1: size limit)"), NumberFormatter.localizedString(from: NSNumber(value: maxLength), number: .none))
        case .responseTimeout:
            return NSLocalizedString("Pump did not respond in time", comment: "Response timeout error description")
        case .unsupportedCommand:
            return NSLocalizedString("RileyLink firmware does not support the given command", comment: "Unsupported command error description")
        }
    }

    public var failureReason: String? {
        switch self {
        case .peripheralManagerError(let error):
            return error.failureReason
        default:
            return errorDescription
        }
    }
}
