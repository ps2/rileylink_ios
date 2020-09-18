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
                        if error.localizedDescription.isEmpty {
                            response = String(describing: error)
                        } else {
                            response = error.localizedDescription
                        }
                    } else {
                        response = messageWithRecovery
                    }
                } else if let localizedError = error as? LocalizedError, !localizedError.localizedDescription.isEmpty {
                    response = localizedError.localizedDescription
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

    static func readPodStatus(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.readPodStatus() { (response) in
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Read Pod Status…", comment: "Progress message for reading Pod status.")
        }
    }

    static func testingCommands(pumpManager: OmnipodPumpManager) -> T {
        return T { (completionHandler) -> String in
            pumpManager.testingCommands() { (error) in
                let response: String
                if let localizedError = error as? LocalizedError, !localizedError.localizedDescription.isEmpty {
                    response = localizedError.localizedDescription
                } else if error != nil {
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
                if let localizedError = error as? LocalizedError, !localizedError.localizedDescription.isEmpty {
                    response = localizedError.localizedDescription
                } else if error != nil {
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
