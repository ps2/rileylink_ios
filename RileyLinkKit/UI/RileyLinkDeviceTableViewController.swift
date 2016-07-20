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
    
    var rssiFetchTimer: NSTimer!

    private var appeared = false

    convenience init() {
        self.init(style: .Grouped)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = device.name

        self.observe()
        
        rssiFetchTimer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: #selector(updateRSSI), userInfo: nil, repeats: true)
    }
    
    func updateRSSI()
    {
        device.peripheral.readRSSI()
    }

    // References to registered notification center observers
    private var notificationObservers: [AnyObject] = []
    
    deinit {
        for observer in notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }

    private var deviceObserver: AnyObject? {
        willSet {
            if let observer = deviceObserver {
                NSNotificationCenter.defaultCenter().removeObserver(observer)
            }
        }
    }

    private func observe() {
        let center = NSNotificationCenter.defaultCenter()
        let mainQueue = NSOperationQueue.mainQueue()
        
        notificationObservers = [
            center.addObserverForName(RileyLinkDeviceManager.NameDidChangeNotification, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = NSIndexPath(forRow: DeviceRow.CustomName.rawValue, inSection: Section.Device.rawValue)
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                self?.title = self?.device.name
            },
            center.addObserverForName(RileyLinkDeviceManager.ConnectionStateDidChangeNotification, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = NSIndexPath(forRow: DeviceRow.Connection.rawValue, inSection: Section.Device.rawValue)
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            },
            center.addObserverForName(RileyLinkDeviceManager.RSSIDidChangeNotification, object: nil, queue: mainQueue) { [weak self = self] (note) -> Void in
                let indexPath = NSIndexPath(forRow: DeviceRow.RSSI.rawValue, inSection: Section.Device.rawValue)
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            }
        ]
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if appeared {
            tableView.reloadData()
        }

        appeared = true
    }
    
    public override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        rssiFetchTimer.invalidate()
        rssiFetchTimer = nil
    }


    // MARK: - Formatters

    private lazy var dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()

        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.timeStyle = .MediumStyle

        return dateFormatter
    }()

    private lazy var decimalFormatter: NSNumberFormatter = {
        let decimalFormatter = NSNumberFormatter()

        decimalFormatter.numberStyle = .DecimalStyle
        decimalFormatter.minimumSignificantDigits = 5

        return decimalFormatter
    }()

    private lazy var successText = NSLocalizedString("Succeeded", comment: "A message indicating a command succeeded")

    // MARK: - Table view data source

    private enum Section: Int {
        case Device
        case Pump
        case Commands

        static let count = 3
    }

    private enum DeviceRow: Int {
        case CustomName
        case Version
        case RSSI
        case Connection
        case IdleStatus

        static let count = 5
    }

    private enum PumpRow: Int {
        case ID
        case Model
        case Awake

        static let count = 3
    }

    private enum CommandRow: Int {
        case Tune
        case ChangeTime
        case MySentryPair
        case DumpHistory
        case GetPumpModel
        case PressDownButton
        case ReadRemainingInsulin

        static let count = 7
    }

    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if device.pumpState == nil {
            return Section.count - 1
        } else {
            return Section.count
        }
    }

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Device:
            return DeviceRow.count
        case .Pump:
            return PumpRow.count
        case .Commands:
            return CommandRow.count
        }
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        if let reusableCell = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) {
            cell = reusableCell
        } else {
            cell = UITableViewCell(style: .Value1, reuseIdentifier: CellIdentifier)
        }

        cell.accessoryType = .None

        switch Section(rawValue: indexPath.section)! {
        case .Device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .CustomName:
                cell.textLabel?.text = NSLocalizedString("Name", comment: "The title of the cell showing device name")
                cell.detailTextLabel?.text = device.name
                cell.accessoryType = .DisclosureIndicator
            case .Version:
                cell.textLabel?.text = NSLocalizedString("Firmware Version", comment: "The title of the cell showing firmware version")
                cell.detailTextLabel?.text = device.firmwareVersion
            case .Connection:
                cell.textLabel?.text = NSLocalizedString("Connection State", comment: "The title of the cell showing BLE connection state")
                cell.detailTextLabel?.text = device.peripheral.state.description
            case .RSSI:
                cell.textLabel?.text = NSLocalizedString("Signal Strength", comment: "The title of the cell showing BLE signal strength (RSSI)")
                if let RSSI = device.RSSI {
                    cell.detailTextLabel?.text = "\(RSSI) dB"
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            case .IdleStatus:
                cell.textLabel?.text = NSLocalizedString("On Idle", comment: "The title of the cell showing the last idle")

                if let idleDate = device.lastIdle {
                    cell.detailTextLabel?.text = dateFormatter.stringFromDate(idleDate)
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            }
        case .Pump:
            switch PumpRow(rawValue: indexPath.row)! {
            case .ID:
                cell.textLabel?.text = NSLocalizedString("Pump ID", comment: "The title of the cell showing pump ID")
                if let pumpID = device.pumpState?.pumpID {
                    cell.detailTextLabel?.text = pumpID
                } else {
                    cell.detailTextLabel?.text = "–"
                }
            case .Model:
                cell.textLabel?.text = NSLocalizedString("Pump Model", comment: "The title of the cell showing the pump model number")
                if let pumpModel = device.pumpState?.pumpModel {
                    cell.detailTextLabel?.text = String(pumpModel)
                } else {
                    cell.detailTextLabel?.text = NSLocalizedString("Unknown", comment: "The detail text for an unknown pump model")
                }
            case .Awake:
                switch device.pumpState?.awakeUntil {
                case let until? where until.timeIntervalSinceNow < 0:
                    cell.textLabel?.text = NSLocalizedString("Last Awake", comment: "The title of the cell describing an awake radio")
                    cell.detailTextLabel?.text = dateFormatter.stringFromDate(until)
                case let until?:
                    cell.textLabel?.text = NSLocalizedString("Awake Until", comment: "The title of the cell describing an awake radio")
                    cell.detailTextLabel?.text = dateFormatter.stringFromDate(until)
                default:
                    cell.textLabel?.text = NSLocalizedString("Listening Off", comment: "The title of the cell describing no radio awake data")
                    cell.detailTextLabel?.text = nil
                }
            }
        case .Commands:
            cell.accessoryType = .DisclosureIndicator
            cell.detailTextLabel?.text = nil

            switch CommandRow(rawValue: indexPath.row)! {
            case .Tune:
                switch (device.radioFrequency, device.lastTuned) {
                case (let frequency?, let date?):
                    cell.textLabel?.text = "\(decimalFormatter.stringFromNumber(frequency)!) MHz"
                    cell.detailTextLabel?.text = dateFormatter.stringFromDate(date)
                default:
                    cell.textLabel?.text = NSLocalizedString("Tune Radio Frequency", comment: "The title of the command to re-tune the radio")
                }

            case .ChangeTime:
                cell.textLabel?.text = NSLocalizedString("Change Time", comment: "The title of the command to change pump time")

                let localTimeZone = NSTimeZone.defaultTimeZone()
                let localTimeZoneName = localTimeZone.abbreviation ?? localTimeZone.name

                if let pumpTimeZone = device.pumpState?.timeZone {
                    let timeZoneDiff = NSTimeInterval(pumpTimeZone.secondsFromGMT - localTimeZone.secondsFromGMT)
                    let formatter = NSDateComponentsFormatter()
                    formatter.allowedUnits = [.Hour, .Minute]
                    let diffString = timeZoneDiff != 0 ? formatter.stringFromTimeInterval(abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""

                    cell.detailTextLabel?.text = String(format: NSLocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
                } else {
                    cell.detailTextLabel?.text = localTimeZoneName
                }
            case .MySentryPair:
                cell.textLabel?.text = NSLocalizedString("MySentry Pair", comment: "The title of the command to pair with mysentry")

            case .DumpHistory:
                cell.textLabel?.text = NSLocalizedString("Fetch Recent History", comment: "The title of the command to fetch recent history")

            case .GetPumpModel:
                cell.textLabel?.text = NSLocalizedString("Get Pump Model", comment: "The title of the command to get pump model")

            case .PressDownButton:
                cell.textLabel?.text = NSLocalizedString("Send Button Press", comment: "The title of the command to send a button press")

            case .ReadRemainingInsulin:
                cell.textLabel?.text = NSLocalizedString("Read Remaining Insulin", comment: "The title of the command to read remaining insulin")
            }
        }

        return cell
    }

    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .Device:
            return NSLocalizedString("Device", comment: "The title of the section describing the device")
        case .Pump:
            return NSLocalizedString("Pump", comment: "The title of the section describing the pump")
        case .Commands:
            return NSLocalizedString("Commands", comment: "The title of the section describing commands")
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .Device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .CustomName:
                return true
            default:
                return false
            }
        case .Pump:
            return false
        case .Commands:
            return device.peripheral.state == .Connected
        }
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .Device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .CustomName:
                let vc = TextFieldTableViewController()
                if let cell = tableView.cellForRowAtIndexPath(indexPath) {
                    vc.title = cell.textLabel?.text
                    vc.value = device.name
                    vc.delegate = self
                    vc.keyboardType = .Default
                }

                showViewController(vc, sender: indexPath)
            default:
                break
            }
        case .Commands:
            let vc: CommandResponseViewController

            switch CommandRow(rawValue: indexPath.row)! {
            case .Tune:
                vc = CommandResponseViewController(command: { [unowned self] (completionHandler) -> String in
                    self.device.tunePumpWithResultHandler({ (response) -> Void in
                        switch response {
                        case .Success(let scanResult):
                            var resultDict: [String: AnyObject] = [:]

                            let intFormatter = NSNumberFormatter()

                            let formatString = NSLocalizedString("%1$@ MHz  %2$@/%3$@  %4$@", comment: "The format string for displaying a frequency tune trial. Extra spaces added for emphesis: (1: frequency in MHz)(2: success count)(3: total count)(4: average RSSI)")

                            resultDict[NSLocalizedString("Best Frequency", comment: "The label indicating the best radio frequency")] = self.decimalFormatter.stringFromNumber(scanResult.bestFrequency)!
                            resultDict[NSLocalizedString("Trials", comment: "The label indicating the results of each frequency trial")] = scanResult.trials.map({ (trial) -> String in

                                return String(format: formatString,
                                    self.decimalFormatter.stringFromNumber(trial.frequencyMHz)!,
                                    intFormatter.stringFromNumber(trial.successes)!,
                                    intFormatter.stringFromNumber(trial.tries)!,
                                    intFormatter.stringFromNumber(trial.avgRSSI)!
                                )
                            })

                            var responseText: String

                            if let data = try? NSJSONSerialization.dataWithJSONObject(resultDict, options: .PrettyPrinted), string = String(data: data, encoding: NSUTF8StringEncoding) {
                                responseText = string
                            } else {
                                responseText = NSLocalizedString("No response", comment: "Message display when no response from tuning pump")
                            }

                            completionHandler(responseText: responseText)
                        case .Failure(let error):
                            completionHandler(responseText: String(error))
                        }
                    })

                    return NSLocalizedString("Tuning radio…", comment: "Progress message for tuning radio")
                })
            case .ChangeTime:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.syncPumpTime { (error) -> Void in
                        dispatch_async(dispatch_get_main_queue()) {
                            if let error = error {
                                completionHandler(responseText: String(error))
                            } else {
                                completionHandler(responseText: self.successText)
                            }
                        }
                    }

                    return NSLocalizedString("Changing time…", comment: "Progress message for changing pump time.")
                }
            case .MySentryPair:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in

                    self.device.ops?.setRXFilterMode(.Wide) { (error) in
                        if let error = error {
                            completionHandler(responseText: String(format: NSLocalizedString("Error setting filter bandwidth: %@", comment: "The error displayed during MySentry pairing when the RX filter could not be set"), String(error)))
                        } else {
                            var byteArray = [UInt8](count: 16, repeatedValue: 0)
                            self.device.peripheral.identifier.getUUIDBytes(&byteArray)
                            let watchdogID = NSData(bytes: &byteArray, length: 3)

                            self.device.ops?.changeWatchdogMarriageProfile(watchdogID, completion: { (error) in
                                dispatch_async(dispatch_get_main_queue()) {
                                    if let error = error {
                                        completionHandler(responseText: String(error))
                                    } else {
                                        completionHandler(responseText: self.successText)
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
            case .DumpHistory:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)!
                    let oneDayAgo = calendar.dateByAddingUnit(.Day, value: -1, toDate: NSDate(), options: [])
                    self.device.ops?.getHistoryEventsSinceDate(oneDayAgo!) { (response) -> Void in
                        switch response {
                        case .Success(let (events, _)):
                            var responseText = String(format:"Found %d events since %@", events.count, oneDayAgo!)
                            for event in events {
                                responseText += String(format:"\nEvent: %@", event.dictionaryRepresentation)
                            }
                            completionHandler(responseText: responseText)
                        case .Failure(let error):
                            completionHandler(responseText: String(error))
                        }
                    }
                    return NSLocalizedString("Fetching history…", comment: "Progress message for fetching pump history.")
                }
            case .GetPumpModel:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.ops?.getPumpModel({ (response) in
                        switch response {
                        case .Success(let model):
                            completionHandler(responseText: "Pump Model: " + model)
                        case .Failure(let error):
                            completionHandler(responseText: String(error))
                        }
                    })
                    return NSLocalizedString("Fetching pump model…", comment: "Progress message for fetching pump model.")
                }
            case .PressDownButton:
                vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.ops?.pressButton({ (response) in
                        dispatch_async(dispatch_get_main_queue()) {
                            switch response {
                            case .Success(let msg):
                                completionHandler(responseText: "Result: " + msg)
                            case .Failure(let error):
                                completionHandler(responseText: String(error))
                            }
                        }
                    })
                    return NSLocalizedString("Sending button press…", comment: "Progress message for sending button press to pump.")
                }
            case .ReadRemainingInsulin:
                vc = CommandResponseViewController {
                    [unowned self] (completionHandler) -> String in
                    self.device.ops?.readRemainingInsulin { (result) in
                        dispatch_async(dispatch_get_main_queue()) {
                            switch result {
                            case .Success(let units):
                                completionHandler(responseText: String(format: NSLocalizedString("%1$@ Units remaining", comment: "The format string describing units of insulin remaining: (1: number of units)"), self.decimalFormatter.stringFromNumber(units)!))
                            case .Failure(let error):
                                completionHandler(responseText: String(error))
                            }
                        }
                    }

                    return NSLocalizedString("Reading remaining insulin…", comment: "Progress message for reading pump insulin reservoir volume")
                }
            }

            if let cell = tableView.cellForRowAtIndexPath(indexPath) {
                vc.title = cell.textLabel?.text
            }

            showViewController(vc, sender: indexPath)
        case .Pump:
            break
        }
    }

    // MARK: - TextFieldTableViewControllerDelegate

    func textFieldTableViewControllerDidReturn(controller: TextFieldTableViewController) {
        navigationController?.popViewControllerAnimated(true)
    }

    func textFieldTableViewControllerDidEndEditing(controller: TextFieldTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .Device:
                switch DeviceRow(rawValue: indexPath.row)! {
                case .CustomName:
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
