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
                        response = String(describing: error)
                    } else {
                        response = messageWithRecovery
                    }
                } else if let error = error {
                    response = String(describing: error)
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

    static func testingCommands(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.testingCommands() { (error) in
                let response: String
                if let error = error {
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
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
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Play Test Beeps…", comment: "Progress message for play test beeps.")
        }
    }

    static func enableConfirmationBeeps(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.enableConfirmationBeeps() { (error) in
                let response: String
                if let error = error {
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Enable Confirmation Beeps…", comment: "Progress message for enable confirmation beeps.")
        }
    }

    static func disableConfirmationBeeps(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.disableConfirmationBeeps() { (error) in
                let response: String
                if let error = error {
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Disable Confirmation Beeps…", comment: "Progress message for disable confirmation beeps.")
        }
    }

    static func enableOptionalPodAlarms(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.enableOptionalPodAlarms() { (error) in
                let response: String
                if let error = error {
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Enable Optional Pod Alarms…", comment: "Progress message for enable optional pod alarms.")
        }
    }

    static func disableOptionalPodAlarms(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.disableOptionalPodAlarms() { (error) in
                let response: String
                if let error = error {
                    response = String(describing: error)
                } else {
                    response = self.successText
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Disable Optional Pod Alarms…", comment: "Progress message for disable optional pod alarms.")
        }
    }
}
