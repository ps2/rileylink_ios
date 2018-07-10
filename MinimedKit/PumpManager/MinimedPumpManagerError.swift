//
//  MinimedPumpManagerError.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation

public enum MinimedPumpManagerError: Error {
    case noRileyLink
    case noDate
    case noDelegate
    case tuneFailed(LocalizedError)
}


extension MinimedPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noRileyLink:
            return nil
        case .noDate:
            return nil
        case .noDelegate:
            return nil
        case .tuneFailed(let error):
            return [NSLocalizedString("RileyLink radio tune failed", comment: "Error description"), error.errorDescription].compactMap({ $0 }).joined(separator: ". ")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noRileyLink:
            return NSLocalizedString("Make sure your RileyLink is nearby and powered on", comment: "Recovery suggestion")
        case .noDate:
            return nil
        case .noDelegate:
            return nil
        case .tuneFailed(_):
            return nil
        }
    }
}
