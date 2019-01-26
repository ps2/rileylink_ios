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
        
        if let omnipodPairingViewController = topViewController as? PairPodSetupViewController, let rileyLinkPumpManager = rileyLinkPumpManager {
            omnipodPairingViewController.rileyLinkPumpManager = rileyLinkPumpManager
        }
    }
        
    private(set) var pumpManager: OmnipodPumpManager?
    
    /*
     1. RileyLink
     - RileyLinkPumpManagerState
     
     2. Basal Rates & Delivery Limits
     
     3. Pod Pairing/Priming
     
     4. Cannula Insertion
     
     5. Pod Setup Complete
     */
    
    override public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)

        // Read state values
        let viewControllers = navigationController.viewControllers
        let count = navigationController.viewControllers.count
        
        if count >= 2 {
            switch viewControllers[count - 2] {
            case let vc as PairPodSetupViewController:
                pumpManager = vc.pumpManager
            default:
                break
            }
        }

        // Set state values
        switch viewController {
        case let vc as PairPodSetupViewController:
            vc.rileyLinkPumpManager = rileyLinkPumpManager
        case let vc as InsertCannulaSetupViewController:
            vc.pumpManager = pumpManager
        default:
            break
        }        
    }

    
    func completeSetup() {
        if let pumpManager = pumpManager {
            setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
        }
    }
}
