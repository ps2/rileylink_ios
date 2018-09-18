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
    
    static func changeTime(podComms: PodComms?, rileyLinkDeviceProvider: RileyLinkDeviceProvider) -> T {
        return T { (completionHandler) -> String in
            podComms?.runSession(withName: "Set time", using: rileyLinkDeviceProvider.firstConnectedDevice) { (result) in
                let response: String
                switch result {
                case .success(let session):
                    do {
                        try session.setTime(basalSchedule: temporaryBasalSchedule, timeZone: .currentFixed, date: Date())
                        response = self.successText
                    } catch let error {
                        response = String(describing: error)
                    }
                case .failure(let error):
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Changing time…", comment: "Progress message for changing pod time.")
        }
    }


    static func testCommand(podComms: PodComms?, rileyLinkDeviceProvider: RileyLinkDeviceProvider) -> T {
        return T { (completionHandler) -> String in
            podComms?.runSession(withName: "Testing Commands", using: rileyLinkDeviceProvider.firstConnectedDevice) { (result) in
                let response: String
                switch result {
                case .success(let session):
                    do {
                        try session.testingCommands()
                        response = self.successText
                    } catch let error {
                        response = String(describing: error)
                    }
                case .failure(let error):
                    response = String(describing: error)
                }
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            return LocalizedString("Testing Commands…", comment: "Progress message for testing commands.")
        }
    }
}
