//
//  RileyLinkDeviceTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import MinimedKit
import RileyLinkBLEKit
import RileyLinkKit

let CellIdentifier = "Cell"

public class RileyLinkDeviceTableViewController: UITableViewController {

    public let device: RileyLinkDevice

    private var deviceState: DeviceState

    private let ops: PumpOps?

    private var pumpState: PumpState? {
        didSet {
            // Update the UI if its visible
            guard rssiFetchTimer != nil else { return }

            switch (oldValue, pumpState) {
            case (.none, .some):
                tableView.insertSections(IndexSet(integer: Section.commands.rawValue), with: .automatic)
            case (.some, .none):
                tableView.deleteSections(IndexSet(integer: Section.commands.rawValue), with: .automatic)
            case (_, let state?):
                if let cell = cellForRow(.awake) {
                    cell.setAwakeUntil(state.awakeUntil, formatter: dateFormatter)
                }

                if let cell = cellForRow(.model) {
                    cell.setPumpModel(state.pumpModel)
                }
            default:
                break
            }
        }
    }

    private let pumpSettings: PumpSettings?

    private var bleRSSI: Int?

    private var firmwareVersion: String? {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            cellForRow(.version)?.detailTextLabel?.text = firmwareVersion
        }
    }

    private var lastIdle: Date? {
        didSet {
            guard isViewLoaded else {
                return
            }

            cellForRow(.idleStatus)?.setDetailDate(lastIdle, formatter: dateFormatter)
        }
    }
    
    var rssiFetchTimer: Timer? {
        willSet {
            rssiFetchTimer?.invalidate()
        }
    }

    private var appeared = false

    public init(device: RileyLinkDevice, deviceState: DeviceState, pumpSettings: PumpSettings?, pumpState: PumpState?, pumpOps: PumpOps?) {
        self.device = device
        self.deviceState = deviceState
        self.pumpSettings = pumpSettings
        self.pumpState = pumpState
        self.ops = pumpOps

        super.init(style: .grouped)

        updateDeviceStatus()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = device.name

        self.observe()
    }
    
    @objc func updateRSSI() {
        device.readRSSI()
    }

    func updateDeviceStatus() {
        device.getStatus { (status) in
            DispatchQueue.main.async {
                self.lastIdle = status.lastIdle
                self.firmwareVersion = status.firmwareDescription
            }
        }
    }

    // References to registered notification center observers
    private var notificationObservers: [Any] = []
    
    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        notificationObservers = [
            center.addObserver(forName: .DeviceNameDidChange, object: device, queue: mainQueue) { [weak self] (note) -> Void in
                if let cell = self?.cellForRow(.customName) {
                    cell.detailTextLabel?.text = self?.device.name
                }

                self?.title = self?.device.name
            },
            center.addObserver(forName: .DeviceConnectionStateDidChange, object: device, queue: mainQueue) { [weak self] (note) -> Void in
                if let cell = self?.cellForRow(.connection) {
                    cell.detailTextLabel?.text = self?.device.peripheralState.description
                }
            },
            center.addObserver(forName: .DeviceRSSIDidChange, object: device, queue: mainQueue) { [weak self] (note) -> Void in
                self?.bleRSSI = note.userInfo?[RileyLinkDevice.notificationRSSIKey] as? Int

                if let cell = self?.cellForRow(.rssi), let formatter = self?.integerFormatter {
                    cell.setDetailRSSI(self?.bleRSSI, formatter: formatter)
                }
            },
            center.addObserver(forName: .DeviceDidStartIdle, object: device, queue: mainQueue) { [weak self] (note) in
                self?.updateDeviceStatus()
            },
            center.addObserver(forName: .PumpOpsStateDidChange, object: ops, queue: mainQueue) { [weak self] (note) in
                if let state = note.userInfo?[PumpOps.notificationPumpStateKey] as? PumpState {
                    self?.pumpState = state
                }
            }
        ]
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if appeared {
            tableView.reloadData()
        }
        
        rssiFetchTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(updateRSSI), userInfo: nil, repeats: true)
        
        appeared = true
        
        updateRSSI()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rssiFetchTimer = nil
    }


    // MARK: - Formatters

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium

        return dateFormatter
    }()
    
    private lazy var integerFormatter = NumberFormatter()

    private lazy var measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()

        formatter.numberFormatter = decimalFormatter

        return formatter
    }()

    private lazy var decimalFormatter: NumberFormatter = {
        let decimalFormatter = NumberFormatter()

        decimalFormatter.numberStyle = .decimal
        decimalFormatter.minimumSignificantDigits = 5

        return decimalFormatter
    }()

    // MARK: - Table view data source

    private enum Section: Int, CaseCountable {
        case device
        case pump
        case commands
    }

    private enum DeviceRow: Int, CaseCountable {
        case customName
        case version
        case rssi
        case connection
        case idleStatus
    }

    private enum PumpRow: Int, CaseCountable {
        case id
        case model
        case awake
    }

    private enum CommandRow: Int, CaseCountable {
        case tune
        case changeTime
        case mySentryPair
        case dumpHistory
        case fetchGlucose
        case getPumpModel
        case pressDownButton
        case readPumpStatus
        case readBasalSchedule
        case enableLED
        case discoverCommands
    }

    private func cellForRow(_ row: DeviceRow) -> UITableViewCell? {
        return tableView.cellForRow(at: IndexPath(row: row.rawValue, section: Section.device.rawValue))
    }

    private func cellForRow(_ row: PumpRow) -> UITableViewCell? {
        return tableView.cellForRow(at: IndexPath(row: row.rawValue, section: Section.pump.rawValue))
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        if pumpState == nil {
            return Section.count - 1
        } else {
            return Section.count
        }
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .device:
            return DeviceRow.count
        case .pump:
            return PumpRow.count
        case .commands:
            return CommandRow.count
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        if let reusableCell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier) {
            cell = reusableCell
        } else {
            cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifier)
        }

        cell.accessoryType = .none

        switch Section(rawValue: indexPath.section)! {
        case .device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .customName:
                cell.textLabel?.text = NSLocalizedString("Name", comment: "The title of the cell showing device name")
                cell.detailTextLabel?.text = device.name
                cell.accessoryType = .disclosureIndicator
            case .version:
                cell.textLabel?.text = NSLocalizedString("Firmware", comment: "The title of the cell showing firmware version")
                cell.detailTextLabel?.text = firmwareVersion
            case .connection:
                cell.textLabel?.text = NSLocalizedString("Connection State", comment: "The title of the cell showing BLE connection state")
                cell.detailTextLabel?.text = device.peripheralState.description
            case .rssi:
                cell.textLabel?.text = NSLocalizedString("Signal Strength", comment: "The title of the cell showing BLE signal strength (RSSI)")

                cell.setDetailRSSI(bleRSSI, formatter: integerFormatter)
            case .idleStatus:
                cell.textLabel?.text = NSLocalizedString("On Idle", comment: "The title of the cell showing the last idle")
                cell.setDetailDate(lastIdle, formatter: dateFormatter)
            }
        case .pump:
            switch PumpRow(rawValue: indexPath.row)! {
            case .id:
                cell.textLabel?.text = NSLocalizedString("Pump ID", comment: "The title of the cell showing pump ID")
                if let pumpID = pumpSettings?.pumpID {
                    cell.detailTextLabel?.text = pumpID
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            case .model:
                cell.textLabel?.text = NSLocalizedString("Pump Model", comment: "The title of the cell showing the pump model number")
                cell.setPumpModel(pumpState?.pumpModel)
            case .awake:
                cell.setAwakeUntil(pumpState?.awakeUntil, formatter: dateFormatter)
            }
        case .commands:
            cell.accessoryType = .disclosureIndicator
            cell.detailTextLabel?.text = nil

            switch CommandRow(rawValue: indexPath.row)! {
            case .tune:
                switch (deviceState.lastValidFrequency, deviceState.lastTuned) {
                case (let frequency?, let date?):
                    cell.textLabel?.text = measurementFormatter.string(from: frequency)
                    cell.setDetailDate(date, formatter: dateFormatter)
                default:
                    cell.textLabel?.text = NSLocalizedString("Tune Radio Frequency", comment: "The title of the command to re-tune the radio")
                }

            case .changeTime:
                cell.textLabel?.text = NSLocalizedString("Change Time", comment: "The title of the command to change pump time")

                let localTimeZone = TimeZone.current
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier

                if let pumpTimeZone = pumpState?.timeZone {
                    let timeZoneDiff = TimeInterval(pumpTimeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
                    let formatter = DateComponentsFormatter()
                    formatter.allowedUnits = [.hour, .minute]
                    let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""

                    cell.detailTextLabel?.text = String(format: NSLocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
                } else {
                    cell.detailTextLabel?.text = localTimeZoneName
                }
            case .mySentryPair:
                cell.textLabel?.text = NSLocalizedString("MySentry Pair", comment: "The title of the command to pair with mysentry")

            case .dumpHistory:
                cell.textLabel?.text = NSLocalizedString("Fetch Recent History", comment: "The title of the command to fetch recent history")

            case .fetchGlucose:
                cell.textLabel?.text = NSLocalizedString("Fetch Enlite Glucose", comment: "The title of the command to fetch recent glucose")
                
            case .getPumpModel:
                cell.textLabel?.text = NSLocalizedString("Get Pump Model", comment: "The title of the command to get pump model")

            case .pressDownButton:
                cell.textLabel?.text = NSLocalizedString("Send Button Press", comment: "The title of the command to send a button press")

            case .readPumpStatus:
                cell.textLabel?.text = NSLocalizedString("Read Pump Status", comment: "The title of the command to read pump status")

            case .readBasalSchedule:
                cell.textLabel?.text = NSLocalizedString("Read Basal Schedule", comment: "The title of the command to read basal schedule")
            
            case .enableLED:
                cell.textLabel?.text = NSLocalizedString("Enable Diagnostic LEDs", comment: "The title of the command to enable diagnostic LEDs")

            case .discoverCommands:
                cell.textLabel?.text = NSLocalizedString("Discover Commands", comment: "The title of the command to discover commands")
            }
        }

        return cell
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .device:
            return NSLocalizedString("Device", comment: "The title of the section describing the device")
        case .pump:
            return NSLocalizedString("Pump", comment: "The title of the section describing the pump")
        case .commands:
            return NSLocalizedString("Commands", comment: "The title of the section describing commands")
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .customName:
                return true
            default:
                return false
            }
        case .pump:
            return false
        case .commands:
            return device.peripheralState == .connected
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .customName:
                let vc = TextFieldTableViewController()
                if let cell = tableView.cellForRow(at: indexPath) {
                    vc.title = cell.textLabel?.text
                    vc.value = device.name
                    vc.delegate = self
                    vc.keyboardType = .default
                }

                show(vc, sender: indexPath)
            default:
                break
            }
        case .commands:
            let vc: CommandResponseViewController

            switch CommandRow(rawValue: indexPath.row)! {
            case .tune:
                vc = .tuneRadio(ops: ops, device: device, current: deviceState.lastValidFrequency, measurementFormatter: measurementFormatter)
            case .changeTime:
                vc = .changeTime(ops: ops, device: device)
            case .mySentryPair:
                vc = .mySentryPair(ops: ops, device: device)
            case .dumpHistory:
                vc = .dumpHistory(ops: ops, device: device)
            case .fetchGlucose:
                vc = .fetchGlucose(ops: ops, device: device)
            case .getPumpModel:
                vc = .getPumpModel(ops: ops, device: device)
            case .pressDownButton:
                vc = .pressDownButton(ops: ops, device: device)
            case .readPumpStatus:
                vc = .readPumpStatus(ops: ops, device: device, measurementFormatter: measurementFormatter)
            case .readBasalSchedule:
                vc = .readBasalSchedule(ops: ops, device: device, integerFormatter: integerFormatter)
            case .enableLED:
                vc = .enableLEDs(ops: ops, device: device)
            case .discoverCommands:
                vc = .discoverCommands(ops: ops, device: device)
            }

            if let cell = tableView.cellForRow(at: indexPath) {
                vc.title = cell.textLabel?.text
            }

            show(vc, sender: indexPath)
        case .pump:
            break
        }
    }
}


extension RileyLinkDeviceTableViewController: TextFieldTableViewControllerDelegate {
    public func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        _ = navigationController?.popViewController(animated: true)
    }

    public func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .device:
                switch DeviceRow(rawValue: indexPath.row)! {
                case .customName:
                    device.setCustomName(controller.value!)
                default:
                    break
                }
            default:
                break

            }
        }
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

    func setDetailRSSI(_ decibles: Int?, formatter: NumberFormatter) {
        detailTextLabel?.text = formatter.decibleString(from: decibles) ?? "-"
    }

    func setAwakeUntil(_ awakeUntil: Date?, formatter: DateFormatter) {
        switch awakeUntil {
        case let until? where until.timeIntervalSinceNow < 0:
            textLabel?.text = NSLocalizedString("Last Awake", comment: "The title of the cell describing an awake radio")
            setDetailDate(until, formatter: formatter)
        case let until?:
            textLabel?.text = NSLocalizedString("Awake Until", comment: "The title of the cell describing an awake radio")
            setDetailDate(until, formatter: formatter)
        default:
            textLabel?.text = NSLocalizedString("Listening Off", comment: "The title of the cell describing no radio awake data")
            detailTextLabel?.text = nil
        }
    }

    func setPumpModel(_ pumpModel: PumpModel?) {
        if let pumpModel = pumpModel {
            detailTextLabel?.text = String(describing: pumpModel)
        } else {
            detailTextLabel?.text = NSLocalizedString("Unknown", comment: "The detail text for an unknown pump model")
        }
    }
}
