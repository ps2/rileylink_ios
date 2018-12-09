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
let pulsesPerUnit: Double = 20

// Units per second
let bolusDeliveryRate: Double = 0.025

// Default expiration times
let podSoftExpirationTime = TimeInterval(hours:72) - TimeInterval(minutes:1)
let podHardExpirationTime = TimeInterval(hours:79) - TimeInterval(minutes:1)

public enum SetupState: UInt8 {
    case sleeping = 0
    case readyToPair = 1
    case addressAssigned = 2
    case paired = 3
    case pairingExpired = 14
}

// DeliveryStatus used in StatusResponse and PodInfoFaults
public enum DeliveryStatus: UInt8, CustomStringConvertible {
    case suspended = 0
    case normal = 1
    case tempBasalRunning = 2
    case priming = 4
    case bolusInProgress = 5
    case bolusAndTempBasal = 6
    
    public var bolusing: Bool {
        return self == .bolusInProgress || self == .bolusAndTempBasal
    }
    
    public var tempBasalRunning: Bool {
        return self == .tempBasalRunning || self == .bolusAndTempBasal
    }
    
    
    public var description: String {
        switch self {
        case .suspended:
            return LocalizedString("Suspended", comment: "Delivery status when insulin delivery is suspended")
        case .normal:
            return LocalizedString("Normal", comment: "Delivery status when basal is running")
        case .tempBasalRunning:
            return LocalizedString("Temp basal running", comment: "Delivery status when temp basal is running")
        case .priming:
            return LocalizedString("Priming", comment: "Delivery status when pod is priming")
        case .bolusInProgress:
            return LocalizedString("Bolusing", comment: "Delivery status when bolusing")
        case .bolusAndTempBasal:
            return LocalizedString("Bolusing with temp basal", comment: "Delivery status when bolusing and temp basal is running")
        }
    }
}
