//
//  SettingsTableViewController.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 8/29/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit
import MinimedKit
import RileyLinkKit
import RileyLinkKitUI

private let ConfigCellIdentifier = "ConfigTableViewCell"

private let TapToSetString = NSLocalizedString("Tap to set", comment: "The empty-state text for a configuration value")


extension TextFieldTableViewController: IdentifiableClass { }


class SettingsTableViewController: UITableViewController, TextFieldTableViewControllerDelegate {

    fileprivate enum Section: Int {
        case about = 0
        case upload
        case configuration

        static let count = 3
    }
    
    fileprivate enum AboutRow: Int {
        case version = 0
        
        static let count = 1
    }

    fileprivate enum UploadRow: Int {
        case upload = 0

        static let count = 1
    }

    fileprivate enum ConfigurationRow: Int {
        case pumpID = 0
        case pumpRegion
        case nightscout
        case fetchCGM
        static let count = 4
    }
    
    fileprivate var dataManager: DeviceDataManager {
        return DeviceDataManager.sharedManager
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .about:
            return AboutRow.count
        case .upload:
            return UploadRow.count
        case .configuration:
            return ConfigurationRow.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        switch Section(rawValue: indexPath.section)! {
        case .about:
            switch AboutRow(rawValue: indexPath.row)! {
            case .version:
                let versionCell = UITableViewCell(style: .default, reuseIdentifier: "Version")
                versionCell.selectionStyle = .none
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
                versionCell.textLabel?.text = "RileyLink iOS v\(version)"
                
                return versionCell
            }
        case .upload:
            switch UploadRow(rawValue: indexPath.row)! {
            case .upload:
                let switchCell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.className, for: indexPath) as! SwitchTableViewCell

                switchCell.`switch`?.isOn = Config.sharedInstance().uploadEnabled
                switchCell.titleLabel.text = NSLocalizedString("Upload To Nightscout", comment: "The title text for the nightscout upload enabled switch cell")
                switchCell.`switch`?.addTarget(self, action: #selector(uploadEnabledChanged(_:)), for: .valueChanged)
                
                return switchCell
            }
        case .configuration:

            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .pumpID:
                let configCell = tableView.dequeueReusableCell(withIdentifier: ConfigCellIdentifier, for: indexPath)
                configCell.textLabel?.text = NSLocalizedString("Pump ID", comment: "The title text for the pump ID config value")
                configCell.detailTextLabel?.text = dataManager.pumpSettings?.pumpID ?? TapToSetString
                cell = configCell
            case .pumpRegion:
                let configCell = tableView.dequeueReusableCell(withIdentifier: ConfigCellIdentifier, for: indexPath)
                configCell.textLabel?.text = NSLocalizedString("Pump Region", comment: "The title text for the pump Region config value")

                if let pumpRegion = dataManager.pumpSettings?.pumpRegion {
                    configCell.detailTextLabel?.text = String(describing: pumpRegion)
                } else {
                    configCell.detailTextLabel?.text = nil
                }

                cell = configCell
            case .nightscout:
                let configCell = tableView.dequeueReusableCell(withIdentifier: ConfigCellIdentifier, for: indexPath)
                let nightscoutService = dataManager.remoteDataManager.nightscoutService
                
                configCell.textLabel?.text = nightscoutService.title
                configCell.detailTextLabel?.text = nightscoutService.siteURL?.absoluteString ?? TapToSetString
                cell = configCell
            case .fetchCGM:
                let switchCell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.className, for: indexPath) as! SwitchTableViewCell
            
                switchCell.`switch`?.isOn = Config.sharedInstance().fetchCGMEnabled
                switchCell.titleLabel.text = NSLocalizedString("Fetch CGM", comment: "The title text for the pull cgm Data cell")
                switchCell.`switch`?.addTarget(self, action: #selector(fetchCGMEnabledChanged(_:)), for: .valueChanged)
                cell = switchCell
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .about:
            return NSLocalizedString("About", comment: "The title of the about section")
        case .upload:
            return nil
        case .configuration:
            return NSLocalizedString("Configuration", comment: "The title of the configuration section in settings")
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            let sender = tableView.cellForRow(at: indexPath)

            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .pumpID:
                let vc = TextFieldTableViewController()

                vc.placeholder = NSLocalizedString("Enter the 6-digit pump ID", comment: "The placeholder text instructing users how to enter a pump ID")
                vc.value = dataManager.pumpSettings?.pumpID

                if let cell = tableView.cellForRow(at: indexPath) {
                    vc.title = cell.textLabel?.text
                }
                vc.indexPath = indexPath
                vc.delegate = self

                show(vc, sender: indexPath)
            case .pumpRegion:
                let vc = RadioSelectionTableViewController.pumpRegion(dataManager.pumpSettings?.pumpRegion)
                vc.title = sender?.textLabel?.text
                vc.delegate = self
                
                show(vc, sender: sender)
            case .nightscout:
                let service = dataManager.remoteDataManager.nightscoutService
                let vc = AuthenticationViewController(authentication: service)
                vc.authenticationObserver = { [weak self] (service) in
                    self?.dataManager.remoteDataManager.nightscoutService = service
                    
                    self?.tableView.reloadRows(at: [indexPath], with: .none)
                }
                
                show(vc, sender: indexPath)
            default:
                break
            }
        case .upload, .about:
            break
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section)! {
        case .upload, .configuration, .about:
            return nil
        }
    }

    // MARK: - Uploader management

    @objc func uploadEnabledChanged(_ sender: UISwitch) {
        Config.sharedInstance().uploadEnabled = sender.isOn
    }

    // MARK: - CGM Page Fetching Management

    @objc func fetchCGMEnabledChanged(_ sender: UISwitch) {
        Config.sharedInstance().fetchCGMEnabled = sender.isOn
    }

    // MARK: - TextFieldTableViewControllerDelegate

    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        if let indexPath = controller.indexPath {
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .pumpID:
                dataManager.setPumpID(controller.value)
            default:
                break
            }
        }

        tableView.reloadData()
    }

    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {

    }
}


extension SettingsTableViewController: RadioSelectionTableViewControllerDelegate {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController) {
        if let selectedIndex = controller.selectedIndex, let pumpRegion = PumpRegion(rawValue: selectedIndex) {
            dataManager.setPumpRegion(pumpRegion)
            
            tableView.reloadRows(at: [IndexPath(row: ConfigurationRow.pumpRegion.rawValue, section: Section.configuration.rawValue)], with: .none)
        }
    }
}

