//
//  CommandResponseViewController.swift
//  RileyLinkKitUI
//
//  Created by Pete Schwamb on 7/19/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKitUI
import RileyLinkBLEKit

extension CommandResponseViewController {
    typealias T = CommandResponseViewController
    
    static func getStatistics(device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            device.runSession(withName: "Get Statistics") { session in
                let response: String

                do {
                    let stats = try session.getRileyLinkStatistics()
                    response = String(describing: stats)
                } catch let error {
                    response = String(describing: error)
                }

                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            
            return LocalizedString("Get Statistics…", comment: "Progress message for getting statistics.")
        }
    }
    
    static func enableLEDs(device: RileyLinkDevice) -> T {
        return T { (completionHandler) -> String in
            device.enableBLELEDs()
            device.runSession(withName: "Enable LEDs") { session in
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

            return LocalizedString("Enabled Diagnostic LEDs", comment: "Progress message for enabling diagnostic LEDs")
        }
    }
}
