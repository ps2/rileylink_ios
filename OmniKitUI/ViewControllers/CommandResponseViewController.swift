//
//  CommandResponseViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 8/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKitUI
import OmniKit
import RileyLinkBLEKit

extension CommandResponseViewController {
    typealias T = CommandResponseViewController
    
    private static let successText = LocalizedString("Succeeded", comment: "A message indicating a command succeeded")
    
    static func changeTime(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.setTime() { (error) in
                let response: String
                if let error = error as? LocalizedError {
                    let sentenceFormat = LocalizedString("%@.", comment: "Appends a full-stop to a statement")
                    let messageWithRecovery = [error.failureReason, error.recoverySuggestion].compactMap({ $0 }).map({
                        String(format: sentenceFormat, $0)
                    }).joined(separator: "\n")

                    if messageWithRecovery.isEmpty {
                        response = error.localizedDescription
                    } else {
                        response = messageWithRecovery
                    }
                } else if let error = error {
                    response = error.localizedDescription
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Changing time…", comment: "Progress message for changing pod time.")
        }
    }
    
    private static func podStatusString(status: DetailedStatus, configuredAlerts: [AlertSlot: PodAlert]) -> String {
        var result, str: String

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]
        if let timeStr = formatter.string(from: status.timeActive) {
            str = timeStr
        } else {
            str = String(format: LocalizedString("%1$@ minutes", comment: "The format string for minutes (1: number of minutes string)"), String(describing: Int(status.timeActive / 60)))
        }
        result = String(format: LocalizedString("Pod Active: %1$@\n", comment: "The format string for Pod Active: (1: Pod active time string)"), str)

        result += String(format: LocalizedString("Delivery Status: %1$@\n", comment: "The format string for Delivery Status: (1: delivery status string)"), String(describing: status.deliveryStatus))

        result += String(format: LocalizedString("Total Insulin Delivered: %1$@ U\n", comment: "The format string for Total Insulin Delivered: (1: total insulin delivered string)"), status.totalInsulinDelivered.twoDecimals)

        result += String(format: LocalizedString("Reservoir Level: %1$@ U\n", comment: "The format string for Reservoir Level: (1: reservoir level string)"), status.reservoirLevel?.twoDecimals ?? "50+")

        result += String(format: LocalizedString("Last Bolus Not Delivered: %1$@ U\n", comment: "The format string for Last Bolus Not Delivered: (1: bolus not delivered string)"), status.bolusNotDelivered.twoDecimals)

        let alertsDescription = status.unacknowledgedAlerts.map { (slot) -> String in
            if let podAlert = configuredAlerts[slot] {
                return String(describing: podAlert)
            } else {
                return String(describing: slot)
            }
        }
        result += String(format: LocalizedString("Alerts: %1$@\n", comment: "The format string for Alerts: (1: the alerts string)"), alertsDescription.joined(separator: ", "))

        result += String(format: LocalizedString("RSSI: %1$@\n", comment: "The format string for RSSI: (1: RSSI value)"), String(describing: status.radioRSSI))

        result += String(format: LocalizedString("Receiver Low Gain: %1$@\n", comment: "The format string for receiverLowGain: (1: receiverLowGain)"), String(describing: status.receiverLowGain))
        
        if status.faultEventCode.faultType != .noFaults {
            result += "\n" // since we have a fault, report the additional fault related information in a separate section
            result += String(format: LocalizedString("Fault: %1$@\n", comment: "The format string for a fault: (1: The fault description)"), status.faultEventCode.localizedDescription)
            result += String(format: LocalizedString("Previous pod progress: %1$@\n", comment: "The format string for previous pod progress: (1: previous pod progress string)"), String(describing: status.previousPodProgressStatus))
            if let faultEventTimeSinceActivation = status.faultEventTimeSinceActivation, let faultTimeStr = formatter.string(from: faultEventTimeSinceActivation) {
                result += String(format: LocalizedString("Fault time: %1$@\n", comment: "The format string for fault time: (1: fault time string)"), faultTimeStr)
            }
        }

        return result
    }

    static func readPodStatus(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.readPodStatus() { (result) in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let status):
                        let configuredAlerts = pumpManager.state.podState!.configuredAlerts
                        completionHandler(podStatusString(status: status, configuredAlerts: configuredAlerts))
                    case .failure(let error):
                        completionHandler(error.localizedDescription)
                    }
                }
            }
            return LocalizedString("Read Pod Status…", comment: "Progress message for reading Pod status.")
        }
    }

    static func testingCommands(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.testingCommands() { (error) in
                DispatchQueue.main.async {
                    completionHandler(error?.localizedDescription ?? self.successText)
                }
            }
            return LocalizedString("Testing Commands…", comment: "Progress message for testing commands.")
        }
    }

    static func playTestBeeps(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.playTestBeeps() { (error) in
                let response: String
                if let error = error {
                    response = error.localizedDescription
                } else {
                    response = LocalizedString("Play test beeps command sent successfully.\n\nIf you did not hear any beeps from your pod, it's likely that the piezo speaker in your pod is broken.", comment: "Success message for play test beeps.")
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Play Test Beeps…", comment: "Progress message for play test beeps.")
        }
    }

    static func readPulseLog(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.readPulseLog() { (response) in
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Reading Pulse Log…", comment: "Progress message for reading pulse log.")
        }
    }
}

extension Double {
    var twoDecimals: String {
        let reservoirLevel = self
        return String(format: "%.2f", reservoirLevel)
    }
}

