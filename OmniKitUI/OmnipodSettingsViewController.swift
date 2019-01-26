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
    
    var statusError: Error?
    
    var podStatus: StatusResponse?
    
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
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 55
        
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        
        let imageView = UIImageView(image: podImage)
        imageView.contentMode = .center
        imageView.frame.size.height += 18  // feels right
        tableView.tableHeaderView = imageView
        tableView.tableHeaderView?.backgroundColor = UIColor.white
        
        updateStatus()
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
    
    private func updateStatus() {
        let deviceSelector = pumpManager.rileyLinkDeviceProvider.firstConnectedDevice
        pumpManager.podComms.runSession(withName: "Update Status", using: deviceSelector) { (result) in
            do {
                switch result {
                case .success(let session):
                    self.podStatus = try session.getStatus()
                case.failure(let error):
                    throw error
                }
            } catch let error {
                self.statusError = error
            }
            DispatchQueue.main.async {
                self.tableView.reloadSections([Section.status.rawValue], with: .none)
            }
        }
    }
    
    // MARK: - Formatters
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        //dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEE 'at' hm", options: 0, locale: nil)
        return dateFormatter
    }()

    
    // MARK: - Data Source
    
    private enum Section: Int {
        case info = 0
        case configuration
        case status
        case rileyLinks
        case deactivate
        
        static let count = 5
    }
    
    private enum InfoRow: Int {
        case activatedAt = 0
        case expiresAt
        case podAddress
        case podLot
        case podTid
        case piVersion
        case pmVersion
        
        static let count = 7
    }
    
    private enum ConfigurationRow: Int {
        case timeZoneOffset = 0
        case testCommand
        
        static let count = 2
    }
    
    fileprivate enum StatusRow: Int {
        case deliveryStatus = 0
        case podStatus
        case alarms
        case reservoirLevel
        case deliveredInsulin
        case insulinNotDelivered
        
        static let count = 6
    }
    
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .info:
            return InfoRow.count
        case .configuration:
            return ConfigurationRow.count
        case .status:
            return StatusRow.count
        case .rileyLinks:
            return super.tableView(tableView, numberOfRowsInSection: section)
        case .deactivate:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .info:
            return NSLocalizedString("Device Information", comment: "The title of the device information section in settings")
        case .configuration:
            return NSLocalizedString("Configuration", comment: "The title of the configuration section in settings")
        case .status:
            return NSLocalizedString("Status", comment: "The title of the status section in settings")
        case .rileyLinks:
            return super.tableView(tableView, titleForHeaderInSection: section)
        case .deactivate:
            return " "  // Use an empty string for more dramatic spacing
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section)! {
        case .rileyLinks:
            return super.tableView(tableView, viewForHeaderInSection: section)
        case .info, .configuration, .status, .deactivate:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            switch InfoRow(rawValue: indexPath.row)! {
            case .activatedAt:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Active Time", comment: "The title of the cell showing the pod activated at time")
                cell.setDetailAge(-pumpManager.state.podState.activatedAt.timeIntervalSinceNow)
                return cell
            case .expiresAt:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Expires", comment: "The title of the cell showing the pod expiration")
                cell.setDetailDate(pumpManager.state.podState.expiresAt, formatter: dateFormatter)
                return cell
            case .podAddress:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Assigned Address", comment: "The title text for the address assigned to the pod")
                cell.detailTextLabel?.text = String(format:"%04X", pumpManager.state.podState.address)
                return cell
            case .podLot:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Lot", comment: "The title of the cell showing the pod lot id")
                cell.detailTextLabel?.text = String(format:"L%d", pumpManager.state.podState.lot)
                return cell
            case .podTid:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("TID", comment: "The title of the cell showing the pod TID")
                cell.detailTextLabel?.text = String(format:"%07d", pumpManager.state.podState.tid)
                return cell
            case .piVersion:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("PI Version", comment: "The title of the cell showing the pod pi version")
                cell.detailTextLabel?.text = pumpManager.state.podState.piVersion
                return cell
            case .pmVersion:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("PM Version", comment: "The title of the cell showing the pod pm version")
                cell.detailTextLabel?.text = pumpManager.state.podState.pmVersion
                return cell
            }
        case .configuration:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                cell.textLabel?.text = NSLocalizedString("Change Time Zone", comment: "The title of the command to change pump time zone")
                
                let localTimeZone = TimeZone.current
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
                
                let timeZoneDiff = TimeInterval(pumpManager.state.podState.timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""
                
                cell.detailTextLabel?.text = String(format: NSLocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
            case .testCommand:
                cell.textLabel?.text = NSLocalizedString("Test Command", comment: "The title of the command to run the test command")
            }
            
            cell.accessoryType = .disclosureIndicator
            return cell
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            
            switch StatusRow(rawValue: indexPath.row)! {
            case .deliveryStatus:
                cell.textLabel?.text = NSLocalizedString("Delivery", comment: "The title of the cell showing delivery status")
            case .podStatus:
                cell.textLabel?.text = NSLocalizedString("Pod Status", comment: "The title of the cell showing pod status")
            case .alarms:
                cell.textLabel?.text = NSLocalizedString("Alarms", comment: "The title of the cell showing alarm status")
            case .reservoirLevel:
                cell.textLabel?.text = NSLocalizedString("Reservoir", comment: "The title of the cell showing reservoir status")
            case .deliveredInsulin:
                cell.textLabel?.text = NSLocalizedString("Delivery", comment: "The title of the cell showing delivered insulin")
            case .insulinNotDelivered:
                cell.textLabel?.text = NSLocalizedString("Insulin Not Delivered", comment: "The title of the cell showing insulin not delivered")
            }
            cell.setStatusDetail(podStatus: podStatus, statusRow: StatusRow(rawValue: indexPath.row)!)
            return cell
        case .rileyLinks:
            return super.tableView(tableView, cellForRowAt: indexPath)
        case .deactivate:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            
            cell.textLabel?.text = NSLocalizedString("Deactivate Pod", comment: "Title text for the button to remove a pod from Loop")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .deleteColor
            cell.isEnabled = true
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .info, .status:
            return false
        case .configuration, .rileyLinks, .deactivate:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .info, .status:
            break
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                let vc = CommandResponseViewController.changeTime(podComms: pumpManager.podComms, rileyLinkDeviceProvider: pumpManager.rileyLinkDeviceProvider)
                vc.title = sender?.textLabel?.text
                show(vc, sender: indexPath)
            case .testCommand:
                let vc = CommandResponseViewController.testCommand(podComms: pumpManager.podComms, rileyLinkDeviceProvider: pumpManager.rileyLinkDeviceProvider)
                vc.title = sender?.textLabel?.text
                show(vc, sender: indexPath)
            }
        case .rileyLinks:
            let device = devicesDataSource.devices[indexPath.row]
            let vc = RileyLinkDeviceTableViewController(device: device)
            self.show(vc, sender: sender)
        case .deactivate:
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                let deviceSelector = self.pumpManager.rileyLinkDeviceProvider.firstConnectedDevice
                self.pumpManager.podComms.runSession(withName: "Deactivate Pod", using: deviceSelector, { (result) in
                    do {
                        switch result {
                        case .success(let session):
                            let _ = try session.changePod()
                            DispatchQueue.main.async {
                                self.pumpManager.pumpManagerDelegate?.pumpManagerWillDeactivate(self.pumpManager)
                                self.navigationController?.popViewController(animated: true)
                            }
                        case.failure(let error):
                            throw error
                        }
                    } catch let error {
                        self.statusError = error
                        DispatchQueue.main.async {
                            self.tableView.reloadSections([Section.status.rawValue], with: .none)
                        }
                    }
                })
            })
            
            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .info, .status:
            break
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .timeZoneOffset, .testCommand:
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        case .rileyLinks:
            break
        case .deactivate:
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
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
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
            message: NSLocalizedString("Are you sure you want to shutdown this pod?", comment: "Confirmation message for shutting down a pod"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Deactivate Pod", comment: "Button title to deactivate pod"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}

private extension TimeInterval {
    func format(using units: NSCalendar.Unit) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = units
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropLeading
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: self)
    }
}


private extension UITableViewCell {
    func setDetailDate(_ date: Date?, formatter: DateFormatter) {
        if let date = date {
            detailTextLabel?.text = formatter.string(from: date)
        } else {
            detailTextLabel?.text = "-"
        }
    }
    
    func setDetailAge(_ age: TimeInterval?) {
        if let age = age {
            detailTextLabel?.text = age.format(using: [.day, .hour, .minute])
        } else {
            detailTextLabel?.text = ""
        }
    }
    
    private var insulinFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        
        return formatter
    }
    
    func setStatusDetail(podStatus: StatusResponse?, statusRow: OmnipodSettingsViewController.StatusRow) {
        if let podStatus = podStatus {
            switch statusRow {
            case .deliveryStatus:
                detailTextLabel?.text = String(describing: podStatus.deliveryStatus)
            case .podStatus:
                detailTextLabel?.text = String(describing: podStatus.reservoirStatus)
            case .alarms:
                detailTextLabel?.text = String(describing: podStatus.alarms)
            case .reservoirLevel:
                if podStatus.reservoirLevel == StatusResponse.maximumReservoirReading {
                    if let units = insulinFormatter.string(from: StatusResponse.maximumReservoirReading) {
                        detailTextLabel?.text = String(format: LocalizedString(">= %@U", comment: "Format string for reservoir reading when above or equal to maximum reading. (1: The localized amount)"), units)
                    }
                } else {
                    if let reservoirValue = podStatus.reservoirLevel,
                        let units = insulinFormatter.string(from: reservoirValue)
                    {
                        detailTextLabel?.text = String(format: LocalizedString("%@ U", comment: "Format string for insulin remaining in reservoir. (1: The localized amount)"), units)
                    } else {
                        detailTextLabel?.text = String(format: LocalizedString(">50 U", comment: "String shown when reservoir is above its max measurement capacity"))
                    }
                }
            case .deliveredInsulin:
                if let units = insulinFormatter.string(from: podStatus.insulin) {
                    detailTextLabel?.text = String(format: LocalizedString("%@U", comment: "Format string for delivered insulin. (1: The localized amount)"), units)
                }
            case .insulinNotDelivered:
                if let units = insulinFormatter.string(from: podStatus.insulinNotDelivered) {
                    detailTextLabel?.text = String(format: LocalizedString("%@U", comment: "Format string for insulin not delivered. (1: The localized amount)"), units)
                }
            }
        } else {
            detailTextLabel?.text = ""
        }
    }

}

