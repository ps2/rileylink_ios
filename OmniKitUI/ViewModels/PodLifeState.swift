//
//  PodLifeState.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 1/31/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import SwiftUI
import LoopKitUI
import OmniKit

// TODO: implement coordinator
enum PodUIScreen {
    case pairPod
    case deactivate
}

enum PodLifeState {
    case podActivating
    // Time remaining
    case timeRemaining(TimeInterval)
    // Time since expiry
    case expiredFor(TimeInterval)
    case podDeactivating
    case podFault(FaultEventCode)
    case noPod
    
    var progress: Double {
        switch self {
        case .timeRemaining(let timeRemaining):
            return max(0, min(1, timeRemaining / Pod.nominalPodLife))
        case .expiredFor(let expiryAge):
            return max(0, min(1, expiryAge / Pod.expirationWindow))
        case .podFault, .podDeactivating:
            return 1
        case .noPod, .podActivating:
            return 0
        }
    }
    
    func progressColor(insulinTintColor: Color, guidanceColors: GuidanceColors) -> Color {
        if case .timeRemaining = self {
            return progress < 0.25 ? guidanceColors.warning : insulinTintColor
        }
        return guidanceColors.critical
    }
    
    func labelColor(using guidanceColors: GuidanceColors) -> Color  {
        if case .podFault = self {
            return guidanceColors.critical
        }
        return .secondary
    }

    
    var localizedLabelText: String {
        switch self {
        case .podActivating:
            return LocalizedString("Unfinished Activation", comment: "Label for pod life state when pod not fully activated")
        case .timeRemaining:
            return LocalizedString("Pod expires in", comment: "Label for pod life state when time remaining")
        case .expiredFor:
            return LocalizedString("Pod expired", comment: "Label for pod life state when within pod expiration window")
        case .podDeactivating:
            return LocalizedString("Unfinished deactivation", comment: "Label for pod life state when pod not fully deactivated")
        case .podFault(let podFault):
            return podFault.localizedDescription
        case .noPod:
            return LocalizedString("No Pod", comment: "Label for pod life state when no pod paired")
        }
    }

    var nextPodLifecycleAction: PodUIScreen {
        switch self {
        case .podActivating, .noPod:
            return .pairPod
        default:
            return .deactivate
        }
    }
    
    var nextPodLifecycleActionDescription: String {
        switch self {
        case .podActivating, .noPod:
            return LocalizedString("Pair New Pod", comment: "Settings page link description when next lifecycle action is to pair new pod")
        case .podDeactivating:
            return LocalizedString("Finish deactivation", comment: "Settings page link description when next lifecycle action is to finish deactivation")
        default:
            return LocalizedString("Replace Pod", comment: "Settings page link description when next lifecycle action is to replace pod")
        }
    }
    
    var nextPodLifecycleActionColor: Color {
        switch self {
        case .podActivating, .noPod:
            return .accentColor
        default:
            return .red
        }
    }

    var isActive: Bool {
        switch self {
        case .expiredFor, .timeRemaining:
            return true
        default:
            return false
        }
    }

    var allowsPumpManagerRemoval: Bool {
        if case .noPod = self {
            return true
        }
        return false
    }
}
