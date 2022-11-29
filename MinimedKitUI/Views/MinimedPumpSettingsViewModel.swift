//
//  MinimedPumpSettingsViewModel.swift
//  MinimedKitUI
//
//  Created by Pete Schwamb on 11/29/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import LoopKit


enum MinimedSettingsViewAlert: Identifiable {
    case suspendError(Error)
    case resumeError(Error)
    case syncTimeError(MinimedPumpManagerError)

    var id: String {
        switch self {
        case .suspendError:
            return "suspendError"
        case .resumeError:
            return "resumeError"
        case .syncTimeError:
            return "syncTimeError"
        }
    }
}

class MinimedPumpSettingsViewModel: ObservableObject {

    @Published var suspendResumeTransitioning: Bool = false
    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState?

    @Published var activeAlert: MinimedSettingsViewAlert?

    var pumpManager: MinimedPumpManager

    init(pumpManager: MinimedPumpManager) {
        self.pumpManager = pumpManager
        self.basalDeliveryState = pumpManager.status.basalDeliveryState

        self.pumpManager.addStatusObserver(self, queue: DispatchQueue.main)
    }

    var pumpImage: UIImage {
        return pumpManager.state.largePumpImage
    }

    func deletePump() {
        
    }

    func didFinish() {
    }

    func suspendResumeButtonPressed(action: SuspendResumeAction) {
        switch action {
        case .resume:
            pumpManager.resumeDelivery { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.activeAlert = .resumeError(error)
                    }
                }
            }
        case .suspend:
            pumpManager.suspendDelivery { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.activeAlert = .suspendError(error)
                    }
                }
            }
        }
    }

    func didChangeInsulinType(_ newType: InsulinType?) {
        self.pumpManager.insulinType = newType
    }
}

extension MinimedPumpSettingsViewModel: PumpManagerStatusObserver {
    public func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        self.basalDeliveryState = status.basalDeliveryState
    }
}


enum SuspendResumeAction {
    case suspend
    case resume
}

extension PumpManagerStatus.BasalDeliveryState {


    var shownAction: SuspendResumeAction {
        switch self {
        case .active, .suspending, .tempBasal, .cancelingTempBasal, .initiatingTempBasal:
            return .suspend
        case .suspended, .resuming:
            return .resume
        }
    }

    var buttonLabelText: String {
        switch self {
        case .active, .tempBasal:
            return LocalizedString("Suspend Delivery", comment: "Title text for button to suspend insulin delivery")
        case .suspending:
            return LocalizedString("Suspending", comment: "Title text for button when insulin delivery is in the process of being stopped")
        case .suspended:
            return LocalizedString("Resume Delivery", comment: "Title text for button to resume insulin delivery")
        case .resuming:
            return LocalizedString("Resuming", comment: "Title text for button when insulin delivery is in the process of being resumed")
        case .initiatingTempBasal:
            return LocalizedString("Starting Temp Basal", comment: "Title text for suspend resume button when temp basal starting")
        case .cancelingTempBasal:
            return LocalizedString("Canceling Temp Basal", comment: "Title text for suspend resume button when temp basal canceling")
        }
    }

    var isTransitioning: Bool {
        switch self {
        case .suspending, .resuming, .initiatingTempBasal, .cancelingTempBasal:
            return true
        default:
            return false
        }
    }

}

