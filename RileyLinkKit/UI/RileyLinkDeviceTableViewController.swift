//
//  RileyLinkDeviceTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import MinimedKit

let CellIdentifier = "Cell"

public class RileyLinkDeviceTableViewController: UITableViewController, TextFieldTableViewControllerDelegate {

    public var device: RileyLinkDevice!
    
    var rssiFetchTimer: Timer? {
        willSet {
            rssiFetchTimer?.invalidate()
        }
    }

    private var appeared = false

    convenience init() {
        self.init(style: .grouped)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = device.name

        self.observe()
    }
    
    @objc func updateRSSI()
    {
        guard case .connected = device.peripheral.state else {
            return
        }
        device.peripheral.readRSSI()
    }

    // References to registered notification center observers
    private var notificationObservers: [Any] = []
    
    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private var deviceObserver: Any? {
        willSet {
            if let observer = deviceObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        notificationObservers = [
            center.addObserver(forName: .DeviceNameDidChange, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = IndexPath(row: DeviceRow.customName.rawValue, section: Section.device.rawValue)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
                self?.title = self?.device.name
            },
            center.addObserver(forName: .DeviceConnectionStateDidChange, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = IndexPath(row: DeviceRow.connection.rawValue, section: Section.device.rawValue)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            },
            center.addObserver(forName: .DeviceRSSIDidChange, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = IndexPath(row: DeviceRow.rssi.rawValue, section: Section.device.rawValue)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
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
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rssiFetchTimer = nil
    }


    // MARK: - Formatters

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        return dateFormatter
    }()

    private lazy var decimalFormatter: NumberFormatter = {
        let decimalFormatter = NumberFormatter()

        decimalFormatter.numberStyle = .decimal
        decimalFormatter.minimumSignificantDigits = 5

        return decimalFormatter
    }()

    private lazy var successText = NSLocalizedString("Succeeded", comment: "A message indicating a command succeeded")

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
        case writeGlucoseHistoryTimestamp
        case getPumpModel
        case pressDownButton
        case readPumpStatus
        case readBasalSchedule
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        if device.pumpState == nil {
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
                cell.detailTextLabel?.text = device.firmwareVersion
            case .connection:
                cell.textLabel?.text = NSLocalizedString("Connection State", comment: "The title of the cell showing BLE connection state")
                cell.detailTextLabel?.text = device.peripheral.state.description
            case .rssi:
                cell.textLabel?.text = NSLocalizedString("Signal Strength", comment: "The title of the cell showing BLE signal strength (RSSI)")
                if let RSSI = device.RSSI {
                    cell.detailTextLabel?.text = "\(RSSI) dB"
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            case .idleStatus:
                cell.textLabel?.text = NSLocalizedString("On Idle", comment: "The title of the cell showing the last idle")

                if let idleDate = device.lastIdle {
                    cell.detailTextLabel?.text = dateFormatter.string(from: idleDate as Date)
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            }
        case .pump:
            switch PumpRow(rawValue: indexPath.row)! {
            case .id:
                cell.textLabel?.text = NSLocalizedString("Pump ID", comment: "The title of the cell showing pump ID")
                if let pumpID = device.pumpState?.pumpID {
                    cell.detailTextLabel?.text = pumpID
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            case .model:
                cell.textLabel?.text = NSLocalizedString("Pump Model", comment: "The title of the cell showing the pump model number")
                if let pumpModel = device.pumpState?.pumpModel {
                    cell.detailTextLabel?.text = String(describing: pumpModel)
                } else {
                    cell.detailTextLabel?.text = NSLocalizedString("Unknown", comment: "The detail text for an unknown pump model")
                }
            case .awake:
                switch device.pumpState?.awakeUntil {
                case let until? where until.timeIntervalSinceNow < 0:
                    cell.textLabel?.text = NSLocalizedString("Last Awake", comment: "The title of the cell describing an awake radio")
                    cell.detailTextLabel?.text = dateFormatter.string(from: until as Date)
                case let until?:
                    cell.textLabel?.text = NSLocalizedString("Awake Until", comment: "The title of the cell describing an awake radio")
                    cell.detailTextLabel?.text = dateFormatter.string(from: until as Date)
                default:
                    cell.textLabel?.text = NSLocalizedString("Listening Off", comment: "The title of the cell describing no radio awake data")
                    cell.detailTextLabel?.text = nil
                }
            }
        case .commands:
            cell.accessoryType = .disclosureIndicator
            cell.detailTextLabel?.text = nil

            switch CommandRow(rawValue: indexPath.row)! {
            case .tune:
                switch (device.radioFrequency, device.lastTuned) {
                case (let frequency?, let date?):
                    cell.textLabel?.text = "\(decimalFormatter.string(from: NSNumber(value: frequency))!) MHz"
                    cell.detailTextLabel?.text = dateFormatter.string(from: date as Date)
                default:
                    cell.textLabel?.text = NSLocalizedString("Tune Radio Frequency", comment: "The title of the command to re-tune the radio")
                }

            case .changeTime:
                cell.textLabel?.text = NSLocalizedString("Change Time", comment: "The title of the command to change pump time")

                let localTimeZone = TimeZone.current
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier

                if let pumpTimeZone = device.pumpState?.timeZone {
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
                cell.textLabel?.text = NSLocalizedString("Fetch Recent Glucose", comment: "The title of the command to fetch recent glucose")
                
            case .writeGlucoseHistoryTimestamp:
                cell.textLabel?.text = NSLocalizedString("Write Glucose History Timestamp", comment: "The title of the command to write a glucose history timestamp")
                
            case .getPumpModel:
                cell.textLabel?.text = NSLocalizedString("Get Pump Model", comment: "The title of the command to get pump model")

            case .pressDownButton:
                cell.textLabel?.text = NSLocalizedString("Send Button Press", comment: "The title of the command to send a button press")

            case .readPumpStatus:
                cell.textLabel?.text = NSLocalizedString("Read Pump Status", comment: "The title of the command to read pump status")

            case .readBasalSchedule:
                cell.textLabel?.text = NSLocalizedString("Read Basal Schedule", comment: "The title of the command to read basal schedule")
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
            return device.peripheral.state == .connected
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
                vc = CommandResponseViewController(command: { [unowned self] (completionHandler) -> String in
                    self.device.tunePump { (response) -> Void in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(let scanResult):
                                var resultDict: [String: Any] = [:]

                                let intFormatter = NumberFormatter()

                                let formatString = NSLocalizedString("%1$@ MHz  %2$@/%3$@  %4$@", comment: "The format string for displaying a frequency tune trial. Extra spaces added for emphesis: (1: frequency in MHz)(2: success count)(3: total count)(4: average RSSI)")

                                resultDict[NSLocalizedString("Best Frequency", comment: "The label indicating the best radio frequency")] = self.decimalFormatter.string(from: NSNumber(value: scanResult.bestFrequency))!
                                resultDict[NSLocalizedString("Trials", comment: "The label indicating the results of each frequency trial")] = scanResult.trials.map({ (trial) -> String in

                                    return String(format: formatString,
                                        self.decimalFormatter.string(from: NSNumber(value: trial.frequencyMHz))!,
                                        intFormatter.string(from: NSNumber(value: trial.successes))!,
                                        intFormatter.string(from: NSNumber(value: trial.tries))!,
                                        intFormatter.string(from: NSNumber(value: trial.avgRSSI))!
                                    )
                                })

                                var responseText: String

                                if let data = try? JSONSerialization.data(withJSONObject: resultDict, options: .prettyPrinted), let string = String(data: data, encoding: String.Encoding.utf8) {
                                    responseText = string
                                } else {
                                    responseText = NSLocalizedString("No response", comment: "Message display when no response from tuning pump")
                                }

                                completionHandler(responseText)
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }

                    return NSLocalizedString("Tuning radio…", comment: "Progress message for tuning radio")
                })
            case .changeTime:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.syncPumpTime { (error) -> Void in
                        DispatchQueue.main.async {
                            if let error = error {
                                completionHandler(String(describing: error))
                            } else {
                                completionHandler(self.successText)
                            }
                        }
                    }

                    return NSLocalizedString("Changing time…", comment: "Progress message for changing pump time.")
                }
            case .mySentryPair:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in

                    self.device.ops?.setRXFilterMode(.wide) { (error) in
                        if let error = error {
                            DispatchQueue.main.async {
                                completionHandler(String(format: NSLocalizedString("Error setting filter bandwidth: %@", comment: "The error displayed during MySentry pairing when the RX filter could not be set"), String(describing: error)))
                            }
                        } else {
                            var byteArray = [UInt8](repeating: 0, count: 16)
                            (self.device.peripheral.identifier as NSUUID).getBytes(&byteArray)
                            let watchdogID = Data(bytes: byteArray[0..<3])

                            self.device.ops?.changeWatchdogMarriageProfile(toWatchdogID: watchdogID, completion: { (error) in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        completionHandler(String(describing: error))
                                    } else {
                                        completionHandler(self.successText)
                                    }
                                }
                            })
                        }
                    }

                    return NSLocalizedString(
                        "On your pump, go to the Find Device screen and select \"Find Device\"." +
                            "\n" +
                            "\nMain Menu >" +
                            "\nUtilities >" +
                            "\nConnect Devices >" +
                            "\nOther Devices >" +
                            "\nOn >" +
                        "\nFind Device",
                        comment: "Pump find device instruction"
                    )
                }
            case .dumpHistory:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                    let oneDayAgo = calendar.date(byAdding: DateComponents(day: -1), to: Date())

                    self.device.ops?.getHistoryEvents(since: oneDayAgo!) { (response) -> Void in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(let (events, _)):
                                var responseText = String(format:"Found %d events since %@", events.count, oneDayAgo! as NSDate)
                                for event in events {
                                    responseText += String(format:"\nEvent: %@", event.dictionaryRepresentation)
                                }
                                completionHandler(responseText)
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    return NSLocalizedString("Fetching history…", comment: "Progress message for fetching pump history.")
                }
            case .fetchGlucose:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                    let oneDayAgo = calendar.date(byAdding: DateComponents(day: -1), to: Date())
                    self.device.ops?.getGlucoseHistoryEvents(since: oneDayAgo!) { (response) -> Void in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(let events):
                                var responseText = String(format:"Found %d events since %@", events.count, oneDayAgo! as NSDate)
                                for event in events {
                                    responseText += String(format:"\nEvent: %@", event.dictionaryRepresentation)
                                }
                                completionHandler(responseText)
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    return NSLocalizedString("Fetching glucose…", comment: "Progress message for fetching pump glucose.")
                }
            case .writeGlucoseHistoryTimestamp:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.ops?.writeGlucoseHistoryTimestamp() { (response) -> Void in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(_):
                                completionHandler("Glucose History timestamp was successfully written to pump.")
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    return NSLocalizedString("Writing glucose history timestamp…", comment: "Progress message for writing glucose history timestamp.")
                }
            case .getPumpModel:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.ops?.getPumpModel { (response) in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(let model):
                                completionHandler("Pump Model: \(model)")
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    return NSLocalizedString("Fetching pump model…", comment: "Progress message for fetching pump model.")
                }
            case .pressDownButton:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.ops?.pressButton { (response) in
                        DispatchQueue.main.async {
                            switch response {
                            case .success(let msg):
                                completionHandler("Result: \(msg)")
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    return NSLocalizedString("Sending button press…", comment: "Progress message for sending button press to pump.")
                }
            case .readPumpStatus:
                vc = CommandResponseViewController {
                    [unowned self] (completionHandler) -> String in
                    self.device.ops?.readPumpStatus { (result) in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let status):
                                var str = String(format: NSLocalizedString("%1$@ Units of insulin remaining\n", comment: "The format string describing units of insulin remaining: (1: number of units)"), self.decimalFormatter.string(from: NSNumber(value: status.reservoir))!)
                                str += String(format: NSLocalizedString("Battery: %1$@ volts\n", comment: "The format string describing pump battery voltage: (1: battery voltage)"), self.decimalFormatter.string(from: NSNumber(value: status.batteryVolts))!)
                                str += String(format: NSLocalizedString("Suspended: %1$@\n", comment: "The format string describing pump suspended state: (1: suspended)"), String(describing: status.suspended))
                                str += String(format: NSLocalizedString("Bolusing: %1$@\n", comment: "The format string describing pump bolusing state: (1: bolusing)"), String(describing: status.bolusing))
                                completionHandler(str)
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }

                    return NSLocalizedString("Reading pump status…", comment: "Progress message for reading pump status")
                }
            case .readBasalSchedule:
                vc = CommandResponseViewController {
                    [unowned self] (completionHandler) -> String in
                    self.device.ops?.getBasalSettings() { (result) in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let schedule):
                                var str = String(format: NSLocalizedString("%1$@ basal schedule entries\n", comment: "The format string describing number of basal schedule entries: (1: number of entries)"), self.decimalFormatter.string(from: NSNumber(value: schedule.entries.count))!)
                                for entry in schedule.entries {
                                    str += "\(String(describing: entry))\n"
                                }
                                completionHandler(str)
                            case .failure(let error):
                                completionHandler(String(describing: error))
                            }
                        }
                    }
                    
                    return NSLocalizedString("Reading basal schedule…", comment: "Progress message for reading basal schedule")
                }
            }

            if let cell = tableView.cellForRow(at: indexPath) {
                vc.title = cell.textLabel?.text
            }

            show(vc, sender: indexPath)
        case .pump:
            break
        }
    }

    // MARK: - TextFieldTableViewControllerDelegate

    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        _ = navigationController?.popViewController(animated: true)
    }

    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
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
