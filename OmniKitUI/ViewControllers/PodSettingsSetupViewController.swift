//
//  PodSettingsSetupViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 9/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import OmniKit

class PodSettingsSetupViewController: SetupTableViewController {
    
    private var pumpManagerSetupViewController: OmnipodPumpManagerSetupViewController? {
        return setupViewController as? OmnipodPumpManagerSetupViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        footerView.primaryButton.isEnabled = setupViewController?.basalSchedule != nil && (setupViewController?.basalSchedule?.items.count)! > 0
        
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }
    
    fileprivate lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 3
        
        return quantityFormatter
    }()
    
    // MARK: - Table view data source
    
    private enum Section: Int {
        case description
        case configuration
        
        static let count = 2
    }
    
    private enum ConfigurationRow: Int {
        case basalRates
        case deliveryLimits
        
        static let count = 2
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .description:
            return 1
        case .configuration:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .description:
            return tableView.dequeueReusableCell(withIdentifier: "DescriptionCell", for: indexPath)
        case .configuration:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                cell.textLabel?.text = LocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
                
                if let basalRateSchedule = setupViewController?.basalSchedule {
                    let unit = HKUnit.internationalUnit()
                    let total = HKQuantity(unit: unit, doubleValue: basalRateSchedule.total())
                    cell.detailTextLabel?.text = quantityFormatter.string(from: total, for: unit)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                }
            case .deliveryLimits:
                cell.textLabel?.text = LocalizedString("Delivery Limits", comment: "Title text for delivery limits")
                
                if setupViewController?.maxBolusUnits == nil || setupViewController?.maxBasalRateUnitsPerHour == nil {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.EnabledString
                }
            }
            
            cell.accessoryType = .disclosureIndicator
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .description:
            return false
        case .configuration:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .description:
            break
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                let vc = SingleValueScheduleTableViewController(style: .grouped)
                
                if let profile = setupViewController?.basalSchedule {
                    vc.scheduleItems = profile.items
                    vc.timeZone = profile.timeZone
                } else {
                    vc.scheduleItems = []
                    vc.timeZone = .currentFixed
                }
                
                vc.title = sender?.textLabel?.text
                vc.delegate = self
                
                show(vc, sender: sender)
            case .deliveryLimits:
                let vc = DeliveryLimitSettingsTableViewController(style: .grouped)
                
                vc.maximumBasalRatePerHour = setupViewController?.maxBasalRateUnitsPerHour
                vc.maximumBolus = setupViewController?.maxBolusUnits
                
                vc.title = sender?.textLabel?.text
                vc.delegate = self
                
                show(vc, sender: sender)
            }
        }
    }
}

extension PodSettingsSetupViewController: DailyValueScheduleTableViewControllerDelegate {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let controller = controller as? SingleValueScheduleTableViewController {
            
            footerView.primaryButton.isEnabled = controller.scheduleItems.count > 0

            pumpManagerSetupViewController?.basalSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
        }
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.basalRates.rawValue]], with: .none)
    }
}

extension PodSettingsSetupViewController: DeliveryLimitSettingsTableViewControllerDelegate {
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBasalRateUnitsPerHour = vc.maximumBasalRatePerHour
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
    
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBolusUnits = vc.maximumBolus
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
}
