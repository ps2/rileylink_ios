//
//  RileyLinkDeviceViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import RileyLinkKit

class RileyLinkDeviceViewController: UIViewController {
    var device: RileyLinkDevice!
    
    @IBOutlet var nameView: UITextField?
    @IBOutlet var connectingIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        nameView!.text = device.name
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch segue.destinationViewController {
        case let vc as PumpChatViewController:
            vc.device = device
        case let vc as MySentryPairViewController:
            vc.device = device
        default:
            break
        }
    }
}