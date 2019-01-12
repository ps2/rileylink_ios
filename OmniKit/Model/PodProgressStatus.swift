//
//  PodProgressStatus.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PodProgressStatus: UInt8, CustomStringConvertible, Equatable {
    case initialized = 0
    case tankPowerActivated = 1
    case tankFillCompleted = 2
    case pairingSuccess = 3
    case priming = 4
    case readyForBasalSchedule = 5
    case readyForCannulaInsertion = 6
    case cannulaInserting = 7
    case aboveFiftyUnits = 8
    case belowFiftyUnits = 9
    case oneNotUsedButin33 = 10
    case twoNotUsedButin33 = 11
    case threeNotUsedButin33 = 12
    case errorEventLoggedShuttingDown = 13
    case delayedPrime = 14 // Saw this after delaying prime for a day
    case inactive = 15 // ($1C Deactivate Pod or packet header mismatch)
    
    public var readyForDelivery: Bool {
        return self == .belowFiftyUnits || self == .aboveFiftyUnits
    }
    
    public var unfinishedPairing: Bool {
        return self.rawValue < PodProgressStatus.aboveFiftyUnits.rawValue
    }

    public var description: String {
        switch self {
        case .initialized:
            return LocalizedString("Initialized", comment: "Pod inititialized")
        case .tankPowerActivated:
            return LocalizedString("Tank power activated", comment: "Pod power to motor activated")
        case .tankFillCompleted:
            return LocalizedString("Tank fill completed", comment: "Pod tank fill completed")
        case .pairingSuccess:
            return LocalizedString("Paired", comment: "Pod status after pairing")
        case .priming:
            return LocalizedString("Priming", comment: "Pod status when priming")
        case .readyForBasalSchedule:
            return LocalizedString("Ready for basal programming", comment: "Pod state when ready for basal programming")
        case .readyForCannulaInsertion:
            return LocalizedString("Ready to insert cannula", comment: "Pod state when ready for cannula insertion")
        case .cannulaInserting:
            return LocalizedString("Cannula inserting", comment: "Pod state when inserting cannula")
        case .aboveFiftyUnits:
            return LocalizedString("Normal", comment: "Pod state when running above fifty units")
        case .belowFiftyUnits:
            return LocalizedString("Below 50 units", comment: "Pod state when running below fifty units")
        case .oneNotUsedButin33:
            return LocalizedString("oneNotUsedButin33", comment: "Pod state oneNotUsedButin33")
        case .twoNotUsedButin33:
            return LocalizedString("twoNotUsedButin33", comment: "Pod state twoNotUsedButin33")
        case .threeNotUsedButin33:
            return LocalizedString("threeNotUsedButin33", comment: "Pod state threeNotUsedButin33")
        case .errorEventLoggedShuttingDown:
            return LocalizedString("Error event logged, shutting down", comment: "Pod state error event logged shutting down")
        case .delayedPrime:
            return LocalizedString("Pod setup window expired", comment: "Pod state when prime or cannula insertion has not completed in the time allotted")
        case .inactive:
            return LocalizedString("Deactivated", comment: "Pod state when pod has been deactivated")
        }
    }
}
    
