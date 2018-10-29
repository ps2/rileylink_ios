//
//  MinimedPumpSettingsViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKitUI
import MinimedKit
import RileyLinkKitUI


class MinimedPumpSettingsViewController: RileyLinkSettingsViewController {

    let pumpManager: MinimedPumpManager

    init(pumpManager: MinimedPumpManager) {
        self.pumpManager = pumpManager
        super.init(rileyLinkPumpManager: pumpManager, devicesSectionIndex: Section.rileyLinks.rawValue, style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = LocalizedString("Pump Settings", comment: "Title of the pump settings view controller")

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 55

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)

        let imageView = UIImageView(image: pumpManager.state.largePumpImage)
        imageView.contentMode = .bottom
        imageView.frame.size.height += 18  // feels right
        tableView.tableHeaderView = imageView
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
        case batteryChemistry
        case preferredInsulinDataSource

        static let count = 3
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
            return LocalizedString("Configuration", comment: "The title of the configuration section in settings")
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
                cell.textLabel?.text = LocalizedString("Pump ID", comment: "The title text for the pump ID config value")
                cell.detailTextLabel?.text = pumpManager.state.pumpID
                return cell
            case .pumpModel:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = LocalizedString("Pump Model", comment: "The title of the cell showing the pump model number")
                cell.detailTextLabel?.text = String(describing: pumpManager.state.pumpModel)
                return cell
            }
        case .settings:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)

            switch SettingsRow(rawValue: indexPath.row)! {
            case .batteryChemistry:
                cell.textLabel?.text = LocalizedString("Pump Battery Type", comment: "The title text for the battery type value")
                cell.detailTextLabel?.text = String(describing: pumpManager.batteryChemistry)
            case .preferredInsulinDataSource:
                cell.textLabel?.text = LocalizedString("Preferred Data Source", comment: "The title text for the preferred insulin data source config")
                cell.detailTextLabel?.text = String(describing: pumpManager.preferredInsulinDataSource)
            case .timeZoneOffset:
                cell.textLabel?.text = LocalizedString("Change Time Zone", comment: "The title of the command to change pump time zone")

                let localTimeZone = TimeZone.current
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier

                let timeZoneDiff = TimeInterval(pumpManager.state.timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""

                cell.detailTextLabel?.text = String(format: LocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
            }

            cell.accessoryType = .disclosureIndicator
            return cell
        case .rileyLinks:
            return super.tableView(tableView, cellForRowAt: indexPath)
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = LocalizedString("Delete Pump", comment: "Title text for the button to remove a pump from Loop")
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
        let sender = tableView.cellForRow(at: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .info:
            break
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .timeZoneOffset:
                let vc = CommandResponseViewController.changeTime(ops: pumpManager.pumpOps, rileyLinkDeviceProvider: pumpManager.rileyLinkDeviceProvider)
                vc.title = sender?.textLabel?.text

                show(vc, sender: indexPath)
            case .batteryChemistry:
                let vc = RadioSelectionTableViewController.batteryChemistryType(pumpManager.batteryChemistry)
                vc.title = sender?.textLabel?.text
                vc.delegate = self

                show(vc, sender: sender)
            case .preferredInsulinDataSource:
                let vc = RadioSelectionTableViewController.insulinDataSource(pumpManager.preferredInsulinDataSource)
                vc.title = sender?.textLabel?.text
                vc.delegate = self

                show(vc, sender: sender)
            }
        case .rileyLinks:
            let device = devicesDataSource.devices[indexPath.row]

            pumpManager.getOpsForDevice(device) { (pumpOps) in
                DispatchQueue.main.async {
                    let vc = RileyLinkMinimedDeviceTableViewController(
                        device: device,
                        pumpOps: pumpOps
                    )

                    self.show(vc, sender: sender)
                }
            }
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
            case .batteryChemistry:
                break
            case .preferredInsulinDataSource:
                break
            }
        case .rileyLinks:
            break
        case .delete:
            break
        }

        return indexPath
    }
}


extension MinimedPumpSettingsViewController: RadioSelectionTableViewControllerDelegate {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }

        switch Section(rawValue: indexPath.section)! {
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .preferredInsulinDataSource:
                if let selectedIndex = controller.selectedIndex, let dataSource = InsulinDataSource(rawValue: selectedIndex) {
                    pumpManager.preferredInsulinDataSource = dataSource
                }
            case .batteryChemistry:
                if let selectedIndex = controller.selectedIndex, let dataSource = MinimedKit.BatteryChemistryType(rawValue: selectedIndex) {
                    pumpManager.batteryChemistry = dataSource
                }
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
            message: LocalizedString("Are you sure you want to delete this pump?", comment: "Confirmation message for deleting a pump"),
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: LocalizedString("Delete Pump", comment: "Button title to delete pump"),
            style: .destructive,
            handler: { (_) in
                handler()
            }
        ))

        let cancel = LocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}
