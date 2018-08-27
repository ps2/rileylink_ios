//
//  OmnipodSettingsViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 8/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import RileyLinkKitUI
import OmniKit
import LoopKitUI

class OmnipodSettingsViewController: RileyLinkSettingsViewController {

    let pumpManager: OmnipodPumpManager
    
    init(pumpManager: OmnipodPumpManager) {
        self.pumpManager = pumpManager
        super.init(rileyLinkPumpManager: pumpManager, devicesSectionIndex: Section.rileyLinks.rawValue, style: .grouped)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var podImage: UIImage? {
        return UIImage(named: "PodLarge", in: Bundle(for: OmnipodSettingsViewController.self), compatibleWith: nil)!
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Pod Settings", comment: "Title of the pod settings view controller")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
        
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionHeaderHeight = 55
        
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        
        let imageView = UIImageView(image: podImage)
        imageView.contentMode = .center
        imageView.frame.size.height += 18  // feels right
        tableView.tableHeaderView = imageView
        tableView.tableHeaderView?.backgroundColor = UIColor.white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if clearsSelectionOnViewWillAppear {
            // Manually invoke the delegate for rows deselecting on appear
            for indexPath in tableView.indexPathsForSelectedRows ?? [] {
                _ = tableView(tableView, willDeselectRowAt: indexPath)
            }
        }
        
        super.viewWillAppear(animated)
    }
    
    // MARK: - Data Source
    
    private enum Section: Int {
        case info = 0
        case settings
        case rileyLinks
        case delete
        
        static let count = 4
    }
    
    private enum InfoRow: Int {
        case pumpID = 0
        case pumpModel
        
        static let count = 2
    }
    
    private enum SettingsRow: Int {
        case timeZoneOffset = 0
        
        static let count = 1
    }
    
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .info:
            return InfoRow.count
        case .settings:
            return SettingsRow.count
        case .rileyLinks:
            return super.tableView(tableView, numberOfRowsInSection: section)
        case .delete:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .info:
            return nil
        case .settings:
            return NSLocalizedString("Configuration", comment: "The title of the configuration section in settings")
        case .rileyLinks:
            return super.tableView(tableView, titleForHeaderInSection: section)
        case .delete:
            return " "  // Use an empty string for more dramatic spacing
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section)! {
        case .rileyLinks:
            return super.tableView(tableView, viewForHeaderInSection: section)
        case .info, .settings, .delete:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            switch InfoRow(rawValue: indexPath.row)! {
            case .pumpID:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Pod Address", comment: "The title text for the address assigned to the pod")
                cell.detailTextLabel?.text = String(format:"0x%04X", pumpManager.state.podState.address)
                return cell
            case .pumpModel:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Pod Lot", comment: "The title of the cell showing the pod lot id")
                cell.detailTextLabel?.text = String(format:"0x%04X", pumpManager.state.podState.lot)
                return cell
            }
        case .settings:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            
            switch SettingsRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                cell.textLabel?.text = NSLocalizedString("Change Time Zone", comment: "The title of the command to change pump time zone")
                
                let localTimeZone = TimeZone.current
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
                
                let timeZoneDiff = TimeInterval(pumpManager.state.podState.timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""
                
                cell.detailTextLabel?.text = String(format: NSLocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
            }
            
            cell.accessoryType = .disclosureIndicator
            return cell
        case .rileyLinks:
            return super.tableView(tableView, cellForRowAt: indexPath)
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            
            cell.textLabel?.text = NSLocalizedString("Delete Pump", comment: "Title text for the button to remove a pump from Loop")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .deleteColor
            cell.isEnabled = true
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            return false
        case .settings, .rileyLinks, .delete:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //let sender = tableView.cellForRow(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .info:
            break
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                break
//                let vc = CommandResponseViewController.changeTime(ops: pumpManager.pumpOps, rileyLinkManager: pumpManager.rileyLinkManager)
//                vc.title = sender?.textLabel?.text
//
//                show(vc, sender: indexPath)
            }
        case .rileyLinks:
            break
//            let device = devicesDataSource.devices[indexPath.row]
//
//            pumpManager.getStateForDevice(device) { (deviceState, pumpOps) in
//                DispatchQueue.main.async {
//                    let vc = RileyLinkMinimedDeviceTableViewController(
//                        device: device,
//                        deviceState: deviceState,
//                        pumpOps: pumpOps
//                    )
//
//                    self.show(vc, sender: sender)
//                }
//            }
        case .delete:
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                self.pumpManager.pumpManagerDelegate?.pumpManagerWillDeactivate(self.pumpManager)
                self.navigationController?.popViewController(animated: true)
            })
            
            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            break
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        case .rileyLinks:
            break
        case .delete:
            break
        }
        
        return indexPath
    }
}


extension OmnipodSettingsViewController: RadioSelectionTableViewControllerDelegate {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        switch Section(rawValue: indexPath.section)! {
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            default:
                assertionFailure()
            }
        default:
            assertionFailure()
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}


private extension UIAlertController {
    convenience init(pumpDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to delete this pump?", comment: "Confirmation message for deleting a pump"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Delete Pump", comment: "Button title to delete pump"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}
