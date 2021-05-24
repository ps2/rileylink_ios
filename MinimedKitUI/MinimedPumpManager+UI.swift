//
//  MinimedPumpManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit
import LoopKit
import LoopKitUI
import MinimedKit


extension MinimedPumpManager: PumpManagerUI {
    public static var onboardingImage: UIImage? {
        return UIImage.pumpImage(in: nil, isLargerModel: false, isSmallImage: true)
    }

    static public func setupViewController(initialSettings settings: PumpManagerSetupSettings, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) -> SetupUIResult<PumpManagerViewController, PumpManagerUI> {
        let setupViewController = MinimedPumpManagerSetupViewController.instantiateFromStoryboard()
        setupViewController.maxBasalRateUnitsPerHour = settings.maxBasalRateUnitsPerHour
        setupViewController.maxBolusUnits = settings.maxBolusUnits
        setupViewController.basalSchedule = settings.basalSchedule
        return .userInteractionRequired(setupViewController)
    }

    public func settingsViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) -> PumpManagerViewController {
        let settings = MinimedPumpSettingsViewController(pumpManager: self)
        let nav = PumpManagerSettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & CompletionNotifying) {
        // Return settings for now. No uncertainty handling atm.
        let settings = MinimedPumpSettingsViewController(pumpManager: self)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public var smallImage: UIImage? {
        return state.smallPumpImage
    }
    
    public func hudProvider(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) -> HUDProvider? {
        return MinimedHUDProvider(pumpManager: self, bluetoothProvider: bluetoothProvider, colorPalette: colorPalette)
    }
    
    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
        return MinimedHUDProvider.createHUDView(rawValue: rawValue)
    }
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension MinimedPumpManager {
    
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        pumpOps.runSession(withName: "Save Settings", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            do {
                if let maxBasalRate = viewController.maximumBasalRatePerHour {
                    try session.setMaxBasalRate(unitsPerHour: maxBasalRate)
                }

                if let maxBolus = viewController.maximumBolus {
                    try session.setMaxBolus(units: maxBolus)
                }

                let settings = try session.getSettings()
                completion(.success(maximumBasalRatePerHour: settings.maxBasal, maximumBolus: settings.maxBolus))
            } catch let error {
                self.log.error("Save delivery limit settings failed: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return LocalizedString("Save to Pump…", comment: "Title of button to save delivery limit settings to pump")
    }

    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }

    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}


// MARK: - BasalScheduleTableViewControllerSyncSource
extension MinimedPumpManager {
    public func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (SyncBasalScheduleResult<Double>) -> Void) {
        syncBasalRateSchedule(items: viewController.scheduleItems) { result in
            switch result {
            case .success(let schedule):
                completion(.success(scheduleItems: schedule.items, timeZone: schedule.timeZone))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String {
        return LocalizedString("Save to Pump…", comment: "Title of button to save basal profile to pump")
    }

    public func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String? {
        return nil
    }

    public func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool {
        return false
    }
}

// MARK: - PumpStatusIndicator
extension MinimedPumpManager {
    
    public var pumpStatusHighlight: DeviceStatusHighlight? {
        return nil
    }
    
    public var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return nil
    }
    
    public var pumpStatusBadge: DeviceStatusBadge? {
        return nil
    }
}
