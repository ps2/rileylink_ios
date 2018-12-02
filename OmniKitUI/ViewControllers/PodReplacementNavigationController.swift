//
//  PodReplacementNavigationController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 11/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import OmniKit
import LoopKitUI

class PodReplacementNavigationController: UINavigationController, UINavigationControllerDelegate, SetupNavigationController {
    
    class func instantiatePodReplacementFlow(_ pumpManager: OmnipodPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "PodReplacementFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }

    class func instantiateNewPodFlow(_ pumpManager: OmnipodPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "NewPodFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }
    
    class func instantiateInsertCannulaFlow(_ pumpManager: OmnipodPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "InsertCannulaFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }

    class func instantiateFaultHandlerFlow(_ pumpManager: OmnipodPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "FaultHandlerFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }
    
    private(set) var pumpManager: OmnipodPumpManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        switch viewController {
        case let vc as ReplacePodViewController:
            vc.pumpManager = pumpManager
        case let vc as PairPodSetupViewController:
            vc.pumpManager = pumpManager
        case let vc as InsertCannulaSetupViewController:
            vc.pumpManager = pumpManager
        default:
            break
        }

    }
    
    func cancelSetup() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func completeSetup() {
        self.dismiss(animated: true, completion: nil)
    }
}
