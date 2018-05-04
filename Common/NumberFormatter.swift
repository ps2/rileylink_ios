//
//  NumberFormatter.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

extension NumberFormatter {
    func decibleString(from decibles: Int?) -> String? {
        if let decibles = decibles, let formatted = string(from: NSNumber(value: decibles)) {
            return String(format: NSLocalizedString("%@ dB", comment: "Unit format string for an RSSI value in decibles"), formatted)
        } else {
            return nil
        }
    }
}
