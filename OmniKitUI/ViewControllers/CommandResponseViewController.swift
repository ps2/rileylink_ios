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


    static func runCommand(pumpManager: OmnipodPumpManager, type: RunCommandSessionType) -> T {
        return T { (completionHandler) -> String in
            pumpManager.runCommand(type: type) { (error) in
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
            switch type {
            case .testingCommands:
                return LocalizedString("Testing Commands…", comment: "Progress message for testing commands.")
            case .checkBeeps:
                return LocalizedString("Check Beeps…", comment: "Progress message for check beeps.")
            case .enableConfirmationBeeps:
                return LocalizedString("Enable Confirmation Beeps…", comment: "Progress message for enable confirmation beeps.")
            case .disableConfirmationBeeps:
                return LocalizedString("Disable Confirmation Beeps…", comment: "Progress message for disable confirmation beeps.")
            case .enableOptionalPodAlarms:
                return LocalizedString("Enable Optional Pod Alarms…", comment: "Progress message for enable optional pod alarms.")
            case .disableOptionalPodAlarms:
                return LocalizedString("Disable Optional Pod Alarms…", comment: "Progress message for disable optional pod alarms.")
            }
        }
    }
}
