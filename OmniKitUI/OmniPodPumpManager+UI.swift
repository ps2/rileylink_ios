//
//  OmniPodPumpManager+UI.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import UIKit
import LoopKit
import LoopKitUI
import OmniKit

// TEMPORARY solution to providing basal schedule; will eventually provided by PumpManagerDelegate
// Used during pairing, and during timezone change.
let temporaryBasalSchedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 0.05, startTime: 0)])


extension OmnipodPumpManager: PumpManagerUI {
    
    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController) {
        return OmnipodPumpManagerSetupViewController.instantiateFromStoryboard()
    }
    
    public func settingsViewController() -> UIViewController {
        return OmnipodSettingsViewController(pumpManager: self)
    }
    
    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: OmnipodSettingsViewController.self), compatibleWith: nil)!
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        let reservoirView = OmnipodReservoirView.instantiate()
        if let lastInsulinMeasurements = state.podState.lastInsulinMeasurements,
            let reservoirVolume = lastInsulinMeasurements.reservoirVolume
        {
            let reservoirLevel = min(1, max(0, reservoirVolume / pumpReservoirCapacity))
            reservoirView.reservoirLevel = reservoirLevel
            reservoirView.setReservoirVolume(volume: reservoirVolume, at: lastInsulinMeasurements.validTime)
        }
        self.addReservoirVolumeObserver(reservoirView)
        
//        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
//        batteryLevelHUDView.batteryLevel = state.batteryPercentage
//        self.addBatteryLevelObserver(batteryLevelHUDView)
        
        return [reservoirView]
    }
    
    public func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction? {
        return nil
    }
    
    public var hudViewsRawState: PumpManagerUI.PumpManagerHUDViewsRawState {
        return PumpManagerUI.PumpManagerHUDViewsRawState()
    }
    
    public static func createHUDViews(rawValue: PumpManagerUI.PumpManagerHUDViewsRawState) -> [BaseHUDView] {
        return []
    }
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension OmnipodPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        guard let maxBasalRate = viewController.maximumBasalRatePerHour,
            let maxBolus = viewController.maximumBolus else
        {
            completion(.failure(PodCommsError.invalidData))
            return
        }
        
        completion(.success(maximumBasalRatePerHour: maxBasalRate, maximumBolus: maxBolus))
    }
    
    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return NSLocalizedString("Save", comment: "Title of button to save delivery limit settings")    }
    
    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }
    
    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}

// MARK: - SingleValueScheduleTableViewControllerSyncSource
extension OmnipodPumpManager {
    public func syncScheduleValues(for viewController: SingleValueScheduleTableViewController, completion: @escaping (RepeatingScheduleValueResult<Double>) -> Void) {
        let timeZone = state.podState.timeZone
        podComms.runSession(withName: "Save Basal Profile", using: rileyLinkDeviceProvider.firstConnectedDevice) { (result) in
            do {
                switch result {
                case .success(let session):
                    let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                    let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
                    let _ = try session.cancelDelivery(deliveryType: .all, beepType: .noBeep)
                    let _ = try session.setBasalSchedule(schedule: newSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: 0)
                    completion(.success(scheduleItems: viewController.scheduleItems, timeZone: timeZone))
                case .failure(let error):
                    throw error
                }
            } catch let error {
                self.log.error("Save basal profile failed: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }
    
    public func syncButtonTitle(for viewController: SingleValueScheduleTableViewController) -> String {
        return NSLocalizedString("Sync With Pod", comment: "Title of button to sync basal profile from pod")
    }
    
    public func syncButtonDetailText(for viewController: SingleValueScheduleTableViewController) -> String? {
        return nil
    }
    
    public func singleValueScheduleTableViewControllerIsReadOnly(_ viewController: SingleValueScheduleTableViewController) -> Bool {
        return false
    }
}
