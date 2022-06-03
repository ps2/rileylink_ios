//
//  OmniPodPumpManager+UI.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import LoopKit
import LoopKitUI
import OmniKit
import RileyLinkKitUI

extension OmnipodPumpManager: PumpManagerUI {    
    public static var onboardingImage: UIImage? {
        return UIImage(named: "Onboarding", in: Bundle(for: OmnipodSettingsViewModel.self), compatibleWith: nil)
    }

    public static func setupViewController(initialSettings settings: PumpManagerSetupSettings, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> SetupUIResult<PumpManagerViewController, PumpManagerUI>
    {
        let vc = OmnipodUICoordinator(colorPalette: colorPalette, pumpManagerSettings: settings, allowDebugFeatures: allowDebugFeatures, allowedInsulinTypes: allowedInsulinTypes)
        return .userInteractionRequired(vc)
    }

    public func settingsViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> PumpManagerViewController {
        return OmnipodUICoordinator(pumpManager: self, colorPalette: colorPalette, allowDebugFeatures: allowDebugFeatures, allowedInsulinTypes: allowedInsulinTypes)
    }

    public func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> (UIViewController & CompletionNotifying) {
        return OmnipodUICoordinator(pumpManager: self, colorPalette: colorPalette, allowDebugFeatures: allowDebugFeatures)
    }

    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: OmnipodSettingsViewModel.self), compatibleWith: nil)!
    }

    public func hudProvider(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowedInsulinTypes: [InsulinType]) -> HUDProvider? {
        return OmnipodHUDProvider(pumpManager: self, bluetoothProvider: bluetoothProvider, colorPalette: colorPalette, allowedInsulinTypes: allowedInsulinTypes)
    }
    
    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> BaseHUDView? {
        return OmnipodHUDProvider.createHUDView(rawValue: rawValue)
    }

}

// MARK: - PumpStatusIndicator
extension OmnipodPumpManager {
    public var pumpStatusHighlight: DeviceStatusHighlight? {
        guard state.podState?.fault != nil else {
            return nil
        }

        return PumpStatusHighlight(localizedMessage: LocalizedString("Pod Fault", comment: "Inform the user that there is a pod fault."),
                                                     imageName: "exclamationmark.circle.fill",
                                                     state: .critical)
    }
    
    public var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return lifecycleProgress(for: state)
    }
    
    public var pumpStatusBadge: DeviceStatusBadge? {
        return nil
    }

}
