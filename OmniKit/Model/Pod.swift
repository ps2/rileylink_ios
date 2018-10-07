//
//  Pod.swift
//  OmniKit
//
//  Created by Pete Schwamb on 4/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

// Units
let podPulseSize: Double = 0.05

// Units per second
let bolusDeliveryRate: Double = 0.025

public struct DeliveryType: OptionSet, Equatable {
    public let rawValue: UInt8
    
    public static let none          = DeliveryType(rawValue: 0)
    public static let basal         = DeliveryType(rawValue: 1 << 0)
    public static let tempBasal     = DeliveryType(rawValue: 1 << 1)
    public static let bolus         = DeliveryType(rawValue: 1 << 2)
    public static let extendedBolus = DeliveryType(rawValue: 1 << 3)
    
    public static let all: DeliveryType = [.none, .basal, .tempBasal, .bolus, .extendedBolus]
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}
