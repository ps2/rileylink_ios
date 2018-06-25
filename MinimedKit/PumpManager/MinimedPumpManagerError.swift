//
//  MinimedPumpManagerError.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation

public enum MinimedPumpManagerError: Error {
    case noDate
    case noDelegate
    case tuneFailed(LocalizedError)
}


extension MinimedPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noDate:
            return nil
        case .noDelegate:
            return nil
        case .tuneFailed(let error):
            return [NSLocalizedString("RileyLink radio tune failed", comment: "Error description"), error.errorDescription].compactMap({ $0 }).joined(separator: ". ")
        }
    }
}
