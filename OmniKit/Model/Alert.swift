//
//  Alert.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation


public enum Alert: UInt8, CustomStringConvertible {
    case autoOff            = 0x00
    case unused             = 0x01
    case expirationAdvisory = 0x02  // Alert at 72 hours. "Change Pod now"
    case expirationAlert    = 0x03  // User configurable with PDM, time before pod expiration (72 hours)
    case lowReservoir       = 0x04
    case suspendInProgress  = 0x05
    case suspendEnded       = 0x06
    case timerLimit         = 0x07

    public var bitMaskValue: UInt8 {
        return 1<<rawValue
    }

    public typealias AllCases = [Alert]
    
    static var allCases: AllCases {
        return (0..<8).map { Alert(rawValue: $0)! }
    }
    
    public var description: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto-off alert", comment: "Description for auto-off alert")
        case .unused:
            return LocalizedString("Unused alert #1", comment: "Pod alarm for unused alert")
        case .expirationAdvisory:
            return LocalizedString("Pod expiration advisory alarm", comment: "Description for expiration advisory alarm")
        case .expirationAlert:
            return LocalizedString("Expiration alert", comment: "Description for expiration alert")
        case .lowReservoir:
            return LocalizedString("Low reservoir advisory alarm", comment: "Description for low reservoir alarm")
        case .suspendInProgress:
            return LocalizedString("Suspend confidence reminder", comment: "Confidence reminder when pod is suspended")
        case .suspendEnded:
            return LocalizedString("End of insulin suspend alarm", comment: "Description for end of insulin suspend alarm")
        case .timerLimit:
            return LocalizedString("Timer Expired", comment: "Pod alarm when pod expires")
        }
    }
}

public struct AlertSet: RawRepresentable, Collection, CustomStringConvertible, Equatable {
    
    public typealias RawValue = UInt8
    public typealias Index = Int
    
    public let startIndex: Int
    public let endIndex: Int
    
    private let elements: [Alert]
    
    public static let none = AlertSet(rawValue: 0)
    
    public var rawValue: UInt8 {
        return elements.reduce(0) { $0 | $1.bitMaskValue }
    }
    
    public init(rawValue: UInt8) {
        self.elements = Alert.allCases.filter { rawValue & $0.bitMaskValue != 0 }
        self.startIndex = 0
        self.endIndex = self.elements.count
    }
    
    public subscript(index: Index) -> Alert {
        return elements[index]
    }
    
    public func index(after i: Int) -> Int {
        return i+1
    }
    
    public var description: String {
        if elements.count == 0 {
            return LocalizedString("No alerts", comment: "Pod alert state when no alerts are active")
        } else {
            let alarmDescriptions = elements.map { String(describing: $0) }
            return alarmDescriptions.joined(separator: ", ")
        }
    }
}
