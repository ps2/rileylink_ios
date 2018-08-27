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
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension OmnipodPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        return
    }
    
    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return NSLocalizedString("Save", comment: "Title of button to save delivery limit settings")    }
    
    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }
    
    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return true
    }
}

// MARK: - SingleValueScheduleTableViewControllerSyncSource
extension OmnipodPumpManager {
    public func syncScheduleValues(for viewController: SingleValueScheduleTableViewController, completion: @escaping (RepeatingScheduleValueResult<Double>) -> Void) {
        return // TODO: store basal schedule
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
