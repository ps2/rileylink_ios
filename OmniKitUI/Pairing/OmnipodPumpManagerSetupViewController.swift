//
//  OmnipodPumpManagerSetupViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import UIKit
import LoopKit
import LoopKitUI
import OmniKit
import RileyLinkBLEKit
import RileyLinkKit
import RileyLinkKitUI

// PumpManagerSetupViewController
public class OmnipodPumpManagerSetupViewController: RileyLinkManagerSetupViewController {
    
    class func instantiateFromStoryboard() -> OmnipodPumpManagerSetupViewController {
        return UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: OmnipodPumpManagerSetupViewController.self)).instantiateInitialViewController() as! OmnipodPumpManagerSetupViewController
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        navigationBar.shadowImage = UIImage()
        
        if let omnipodPairingViewController = topViewController as? OmnipodPairingViewController, let rileyLinkPumpManager = rileyLinkPumpManager {
            omnipodPairingViewController.rileyLinkPumpManager = rileyLinkPumpManager
        }
    }
        
    private(set) var pumpManager: OmnipodPumpManager?
    
    /*
     1. RileyLink
     - RileyLinkPumpManagerState
     
     2. Pod Pairing/Priming
     
     3. Basal Rates & Delivery Limits
     
     4. Cannula Insertion
     
     5. Pump Setup Complete
     */
    
    override public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)
        
        // Set state values
        switch viewController {
        case let vc as OmnipodPairingViewController:
            vc.rileyLinkPumpManager = rileyLinkPumpManager
        default:
            break
        }        
    }

    
    func completeSetup() {
        let count = viewControllers.count
        
        if count >= 1 {
            switch viewControllers[count - 1] {
            case let vc as OmnipodPairingViewController:
                pumpManager = vc.pumpManager
            default:
                break
            }
        }
        
        if let pumpManager = pumpManager {
            setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
        }
    }
}
