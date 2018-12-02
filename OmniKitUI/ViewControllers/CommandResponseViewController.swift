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
                if let error = error {
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


    static func testCommand(pumpManager: OmnipodPumpManager) -> T {
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
}
