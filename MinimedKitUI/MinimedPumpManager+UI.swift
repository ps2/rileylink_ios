//
//  MinimedPumpManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MinimedKit


extension MinimedPumpManager: PumpManagerUI {
    
    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController) {
        return MinimedPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> UIViewController {
        return MinimedPumpSettingsViewController(pumpManager: self)
    }

    public var smallImage: UIImage? {
        return state.smallPumpImage
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let lastReservoirVolume = state.lastReservoirReading {
            let reservoirLevel = min(1, max(0, lastReservoirVolume.units / pumpReservoirCapacity))
            reservoirVolumeHUDView.reservoirLevel = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: lastReservoirVolume.units, at: lastReservoirVolume.validAt)
        }
        self.addReservoirVolumeObserver(reservoirVolumeHUDView)
        
        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
        batteryLevelHUDView.batteryLevel = state.batteryPercentage
        self.addBatteryLevelObserver(batteryLevelHUDView)
        
        return [reservoirVolumeHUDView, batteryLevelHUDView]
    }
    
    public func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction? {
        return nil
    }

    public var hudViewsRawState: PumpManagerUI.PumpManagerHUDViewsRawState {
        var rawValue: MinimedPumpManager.PumpManagerHUDViewsRawState = [
            "pumpReservoirCapacity": pumpReservoirCapacity
        ]
        
        if let batteryPercentage = state.batteryPercentage {
            rawValue["batteryPercentage"] = batteryPercentage
        }
        
        if let lastReservoirReading = state.lastReservoirReading {
            rawValue["lastReservoirReading"] = lastReservoirReading.rawValue
        }
        
        return rawValue
    }
    
    public static func createHUDViews(rawValue: PumpManagerUI.PumpManagerHUDViewsRawState) -> [BaseHUDView] {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double else {
            return []
        }
        
        let batteryPercentage = rawValue["batteryPercentage"] as? Double
        
        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let rawLastReservoirReading = rawValue["lastReservoirReading"] as? ReservoirReading.RawValue,
            let lastReservoirReading = ReservoirReading(rawValue: rawLastReservoirReading)
        {
            let reservoirLevel = min(1, max(0, lastReservoirReading.units / pumpReservoirCapacity))
            reservoirVolumeHUDView.reservoirLevel = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: lastReservoirReading.units, at: lastReservoirReading.validAt)
        }
        
        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
        batteryLevelHUDView.batteryLevel = batteryPercentage
        
        return [reservoirVolumeHUDView, batteryLevelHUDView]
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


// MARK: - SingleValueScheduleTableViewControllerSyncSource
extension MinimedPumpManager {
    public func syncScheduleValues(for viewController: SingleValueScheduleTableViewController, completion: @escaping (RepeatingScheduleValueResult<Double>) -> Void) {
        pumpOps.runSession(withName: "Save Basal Profile", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            do {
                let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
                try session.setBasalSchedule(newSchedule, for: .standard)

                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: session.pump.timeZone))
            } catch let error {
                self.log.error("Save basal profile failed: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: SingleValueScheduleTableViewController) -> String {
        return LocalizedString("Save to Pump…", comment: "Title of button to save basal profile to pump")
    }

    public func syncButtonDetailText(for viewController: SingleValueScheduleTableViewController) -> String? {
        return nil
    }

    public func singleValueScheduleTableViewControllerIsReadOnly(_ viewController: SingleValueScheduleTableViewController) -> Bool {
        return false
    }
}

extension BatteryLevelHUDView: BatteryLevelObserver {
    public func batteryLevelDidChange(_ newValue: Double) {
        DispatchQueue.main.async {
            self.batteryLevel = newValue
        }
    }
}

extension ReservoirVolumeHUDView: ReservoirVolumeObserver {
    public func reservoirVolumeDidChange(_ units: Double, at validTime: Date, level: Double?) {
        DispatchQueue.main.async {
            self.reservoirLevel = level
            self.setReservoirVolume(volume: units, at: validTime)
        }
    }
}
