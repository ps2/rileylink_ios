//
//  RileyLinkDeviceTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import MinimedKit

public class RileyLinkDeviceTableViewController: UITableViewController {

    public var device: RileyLinkDevice!

    private var appeared = false

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = device.name
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if appeared {
            tableView.reloadData()
        }

        appeared = true
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
        decimalFormatter.minimumFractionDigits = 2
        decimalFormatter.maximumFractionDigits = 2

        return decimalFormatter
    }()

    // MARK: - Table view data source

    private enum Section: Int {
        case Device
        case Pump
        case Commands

        static let count = 3
    }

    private enum DeviceRow: Int {
        case RSSI
        case Connection
        case IdleStatus

        static let count = 3
    }

    private enum PumpRow: Int {
        case ID
        case Awake

        static let count = 2
    }

    private enum CommandRow: Int {
        case Tune
        case ChangeTime
        case MySentryPair

        static let count = 3
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
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        cell.accessoryType = .None

        switch Section(rawValue: indexPath.section)! {
        case .Device:
            switch DeviceRow(rawValue: indexPath.row)! {
            case .Connection:
                cell.textLabel?.text = NSLocalizedString("Connection State", comment: "The title of the cell showing connection state")
                cell.detailTextLabel?.text = device.peripheral.state.description
            case .RSSI:
                cell.textLabel?.text = NSLocalizedString("Signal strength", comment: "The title of the cell showing signal strength (RSSI)")
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
            case .Awake:
                switch device.pumpState?.awakeUntil {
                case let until? where until < NSDate():
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
            switch CommandRow(rawValue: indexPath.row)! {
            case .Tune:
                switch (device.radioFrequency, device.lastTuned) {
                case (let frequency?, let date?):
                    cell.textLabel?.text = "\(decimalFormatter.stringFromNumber(frequency)!) MHz"
                    cell.detailTextLabel?.text = dateFormatter.stringFromDate(date)
                default:
                    cell.textLabel?.text = NSLocalizedString("Tune radio frequency", comment: "The title of the cell describing the command to re-tune the radio")
                    cell.detailTextLabel?.text = nil
                }
                cell.accessoryType = .DisclosureIndicator
            case .ChangeTime:
                cell.textLabel?.text = "Change Time"
                cell.accessoryType = .DisclosureIndicator

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
                cell.textLabel?.text = "MySentry Pair"
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .DisclosureIndicator
            }
        }

        return cell
    }

    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .Device:
            return NSLocalizedString("Bluetooth", comment: "The title of the section describing the device")
        case .Pump:
            return NSLocalizedString("Pump", comment: "The title of the section describing the pump")
        case .Commands:
            return NSLocalizedString("Commands", comment: "The title of the section describing commands")
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .Device, .Pump:
            return false
        case .Commands:
            return true
        }
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .Commands:
            switch CommandRow(rawValue: indexPath.row)! {
            case .Tune:
                let vc = CommandResponseViewController(command: { [unowned self] (completionHandler) -> String in
                    self.device.tunePumpWithResultHandler({ (response) -> Void in
                        switch response {
                        case .Success(let scanResult):
                            var resultDict: [String: AnyObject] = [:]
                            let decimalFormatter = NSNumberFormatter()
                            decimalFormatter.minimumSignificantDigits = 5

                            resultDict["Best Frequency"] = scanResult.bestFrequency
                            resultDict["Trials"] = scanResult.trials.map({ (trial) -> String in
                                return "\(decimalFormatter.stringFromNumber(trial.frequencyMHz)!) MHz  \(trial.successes)/\(trial.tries)  \(trial.avgRSSI)"
                            })

                            var responseText: String

                            if let data = try? NSJSONSerialization.dataWithJSONObject(resultDict, options: .PrettyPrinted), string = String(data: data, encoding: NSUTF8StringEncoding) {
                                responseText = string
                            } else {
                                responseText = "No response"
                            }

                            completionHandler(responseText: responseText)
                        case .Failure(let error):
                            completionHandler(responseText: String(error))
                        }
                    })

                    return "Tuning radio..."
                })

                vc.title = "Tune device radio"

                self.showViewController(vc, sender: indexPath)
            case .ChangeTime:
                let vc = CommandResponseViewController { [unowned self] (completionHandler) -> String in
                    self.device.syncPumpTime { (error) -> Void in
                        dispatch_async(dispatch_get_main_queue()) {
                            if let error = error {
                                completionHandler(responseText: "Failed: \(error)")
                            } else {
                                completionHandler(responseText: "Succeeded")
                            }
                        }
                    }

                    return "Changing time..."
                }

                vc.title = "Change Time"

                self.showViewController(vc, sender: indexPath)
            case .MySentryPair:
                let vc = self.storyboard!.instantiateViewControllerWithIdentifier("mySentryPair") as! MySentryPairViewController
                
                vc.device = device
                
                vc.title = "MySentry Pair"
                
                self.showViewController(vc, sender: indexPath)
            }
        case .Device, .Pump:
            break
        }
    }
}
