//
//  CommandResponseViewController+RileyLinkDevice.swift
//  RileyLinkKitUI
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import RileyLinkBLEKit
import RileyLinkKit
import MinimedKit
import OmniKit


extension CommandResponseViewController {
    typealias T = CommandResponseViewController

    private static let successText = NSLocalizedString("Succeeded", comment: "A message indicating a command succeeded")

    static func changeTime(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Set time", using: device) { (session) in
                let response: String
                do {
                    try session.setTime { () -> DateComponents in
                        let calendar = Calendar(identifier: .gregorian)
                        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
                    }

                    response = self.successText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Changing time…", comment: "Progress message for changing pump time.")
        }
    }

    static func dumpHistory(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
            let oneDayAgo = calendar.date(byAdding: DateComponents(day: -1), to: Date())

            ops?.runSession(withName: "Get history events", using: device) { (session) in
                let response: String
                do {
                    let (events, _) = try session.getHistoryEvents(since: oneDayAgo!)
                    var responseText = String(format: "Found %d events since %@", events.count, oneDayAgo! as NSDate)
                    for event in events {
                        responseText += String(format:"\nEvent: %@", event.dictionaryRepresentation)
                    }

                    response = responseText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Fetching history…", comment: "Progress message for fetching pump history.")
        }
    }

    static func fetchGlucose(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
            let oneDayAgo = calendar.date(byAdding: DateComponents(day: -1), to: Date())

            ops?.runSession(withName: "Get glucose history", using: device) { (session) in
                let response: String
                do {
                    let events = try session.getGlucoseHistoryEvents(since: oneDayAgo!)
                    var responseText = String(format: "Found %d events since %@", events.count, oneDayAgo! as NSDate)
                    for event in events {
                        responseText += String(format: "\nEvent: %@", event.dictionaryRepresentation)
                    }

                    response = responseText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Fetching glucose…", comment: "Progress message for fetching pump glucose.")
        }
    }

    static func getPumpModel(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Get Pump Model", using: device) { (session) in
                let response: String
                do {
                    let model = try session.getPumpModel(usingCache: false)
                    response = "Pump Model: \(model)"
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Fetching pump model…", comment: "Progress message for fetching pump model.")
        }
    }

    static func mySentryPair(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            var byteArray = [UInt8](repeating: 0, count: 16)
            (device.peripheralIdentifier as NSUUID).getBytes(&byteArray)
            let watchdogID = Data(bytes: byteArray[0..<3])

            ops?.runSession(withName: "Change watchdog marriage profile", using: device) { (session) in
                let response: String
                do {
                    try session.changeWatchdogMarriageProfile(watchdogID)
                    response = self.successText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
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
    }

    static func pressDownButton(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Press down button", using: device) { (session) in
                let response: String
                do {
                    try session.pressButton(.down)
                    response = self.successText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Sending button press…", comment: "Progress message for sending button press to pump.")
        }
    }

    static func readBasalSchedule(ops: PumpOps?, device: RileyLinkDevice, integerFormatter: NumberFormatter) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Get Basal Settings", using: device) { (session) in
                let response: String
                do {
                    let schedule = try session.getBasalSchedule(for: .standard)
                    var str = String(format: NSLocalizedString("%1$@ basal schedule entries\n", comment: "The format string describing number of basal schedule entries: (1: number of entries)"), integerFormatter.string(from: NSNumber(value: schedule.entries.count))!)
                    for entry in schedule.entries {
                        str += "\(String(describing: entry))\n"
                    }
                    response = str
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Reading basal schedule…", comment: "Progress message for reading basal schedule")
        }
    }
    
    static func enableLEDs(ops: PumpOps?, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            device.enableBLELEDs()
            ops?.runSession(withName: "Enable LEDs", using: device) { (session) in
                let response: String
                do {
                    try session.enableCCLEDs()
                    response = "OK"
                } catch let error {
                    response = String(describing: error)
                }
                
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Enabled Diagnostic LEDs", comment: "Progress message for enabling diagnostic LEDs")
        }
    }


    static func readPumpStatus(ops: PumpOps?, device: RileyLinkDevice, decimalFormatter: NumberFormatter) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Read pump status", using: device) { (session) in
                let response: String
                do {
                    let status = try session.getCurrentPumpStatus()

                    var str = String(format: NSLocalizedString("%1$@ Units of insulin remaining\n", comment: "The format string describing units of insulin remaining: (1: number of units)"), decimalFormatter.string(from: NSNumber(value: status.reservoir))!)
                    str += String(format: NSLocalizedString("Battery: %1$@ volts\n", comment: "The format string describing pump battery voltage: (1: battery voltage)"), decimalFormatter.string(from: NSNumber(value: status.batteryVolts))!)
                    str += String(format: NSLocalizedString("Suspended: %1$@\n", comment: "The format string describing pump suspended state: (1: suspended)"), String(describing: status.suspended))
                    str += String(format: NSLocalizedString("Bolusing: %1$@\n", comment: "The format string describing pump bolusing state: (1: bolusing)"), String(describing: status.bolusing))
                    response = str
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Reading pump status…", comment: "Progress message for reading pump status")
        }
    }
    
    static func omniGetStatus(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Get Omnipod Status", using: device, { (session) in
                let response: String
                do {
                    let result = try session.getStatus()
                    response = String(describing: result)
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Reading pump status…", comment: "Progress message for reading pod status")
        }
    }

    static func omniTestSetTempBasal(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Test Set Temp Basal", using: device, { (session) in
                let response: String
                do {
                    let rate = 30.0
                    let duration = TimeInterval(minutes: 30)
                    try session.setTempBasal(rate: rate, duration: duration, confidenceReminder: true, programReminderCounter: 60)
                    response = "Set Temp Basal of \(rate)U/hr for \(duration.minutes) minutes"
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Testing Set Temp Basal…", comment: "Progress message for testing omnipod commands")
        }
    }

    static func omniTestBolus(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Test Bolus", using: device, { (session) in
                let response: String
                do {
                    let amount = 1.0
                    try session.bolus(units: amount)
                    response = "Started bolus of \(amount)U"
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Testing Bolus...", comment: "Progress message for testing omnipod commands")
        }
    }
    
    static func omniTestCancelTempBasal(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Test Cancel Temp Basal", using: device, { (session) in
                let response: String
                do {
                    try session.cancelTempBasal()
                    response = "Canceled Temp Basal"
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Testing Cancel Temp Basal...", comment: "Progress message for testing omnipod commands")
        }
    }


    static func omniTesting(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Testing Commands", using: device, { (session) in
                let response: String
                do {
                    try session.testingCommands()
                    response = "OK"
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Testing omnipod commands…", comment: "Progress message for testing omnipod commands")
        }
    }

    static func omniChangePod(podComms: PodComms, device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            podComms.runSession(withName: "Change Pod", using: device, { (session) in
                let response: String
                do {
                    try session.changePod()
                    response = "OK"
                } catch let error {
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            })
            return NSLocalizedString("Deactivating pod", comment: "Progress message for deactivating pod")
        }
    }

    static func tuneRadio(ops: PumpOps?, device: RileyLinkDevice, current: Measurement<UnitFrequency>?, measurementFormatter: MeasurementFormatter) -> T {
        return T { (completionHandler) -> String in
            ops?.runSession(withName: "Tune pump", using: device) { (session) in
                let response: String
                do {
                    let scanResult = try session.tuneRadio(current: nil)

                    NotificationCenter.default.post(
                        name: .DeviceStateDidChange,
                        object: device,
                        userInfo: [
                            RileyLinkDevice.notificationDeviceStateKey: DeviceState(
                                lastTuned: Date(),
                                lastValidFrequency: scanResult.bestFrequency
                            )
                        ]
                    )

                    var resultDict: [String: Any] = [:]

                    let intFormatter = NumberFormatter()
                    let formatString = NSLocalizedString("%1$@  %2$@/%3$@  %4$@", comment: "The format string for displaying a frequency tune trial. Extra spaces added for emphesis: (1: frequency in MHz)(2: success count)(3: total count)(4: average RSSI)")

                    resultDict[NSLocalizedString("Best Frequency", comment: "The label indicating the best radio frequency")] = measurementFormatter.string(from: scanResult.bestFrequency)
                    resultDict[NSLocalizedString("Trials", comment: "The label indicating the results of each frequency trial")] = scanResult.trials.map({ (trial) -> String in

                        return String(
                            format: formatString,
                            measurementFormatter.string(from: trial.frequency),
                            intFormatter.string(from: NSNumber(value: trial.successes))!,
                            intFormatter.string(from: NSNumber(value: trial.tries))!,
                            intFormatter.string(from: NSNumber(value: trial.avgRSSI))!
                        )
                    })

                    var responseText: String

                    if let data = try? JSONSerialization.data(withJSONObject: resultDict, options: .prettyPrinted), let string = String(data: data, encoding: .utf8) {
                        responseText = string
                    } else {
                        responseText = NSLocalizedString("No response", comment: "Message display when no response from tuning pump")
                    }

                    response = responseText
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }

            return NSLocalizedString("Tuning radio…", comment: "Progress message for tuning radio")
        }
    }
}
