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
    
    public func hudProvider() -> HUDProvider? {
        return OmnipodHUDProvider(pumpManager: self)
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        return OmnipodHUDProvider.createHUDViews(rawValue: rawValue)
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
        return LocalizedString("Save", comment: "Title of button to save delivery limit settings")    }
    
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
        let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
        setBasalSchedule(newSchedule) { (error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: self.state.timeZone))
            }
        }
    }
    
    public func syncButtonTitle(for viewController: SingleValueScheduleTableViewController) -> String {
        return LocalizedString("Sync With Pod", comment: "Title of button to sync basal profile from pod")
    }
    
    public func syncButtonDetailText(for viewController: SingleValueScheduleTableViewController) -> String? {
        return nil
    }
    
    public func singleValueScheduleTableViewControllerIsReadOnly(_ viewController: SingleValueScheduleTableViewController) -> Bool {
        return false
    }
}
