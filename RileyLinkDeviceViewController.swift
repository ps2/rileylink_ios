//
//  RileyLinkDeviceViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import UIKit
import RileyLinkKit

class RileyLinkDeviceViewController : UIViewController {
    
    @IBOutlet var deviceIDLabel: UILabel!
    @IBOutlet var nameView: UITextField!
    @IBOutlet var autoConnectSwitch: UISwitch!
    @IBOutlet var connectingIndicator: UIActivityIndicatorView!
    
    var device: RileyLinkDevice!
    
    var pumpTimeZone: NSTimeZone?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deviceIDLabel.text = device.peripheral.identifier.UUIDString
        nameView.text = device.name
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        
        switch segue.destinationViewController {
        case let vc as MySentryPairViewController:
            vc.device = device
        case let vc as PumpChatViewController:
            vc.device = device
        }
    }

}