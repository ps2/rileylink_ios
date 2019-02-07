//
//  PodSetupCompleteViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 9/18/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKitUI

class PodSetupCompleteViewController: SetupTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = nil
    }
    
    override func continueButtonPressed(_ sender: Any) {
        if let setupVC = navigationController as? OmnipodPumpManagerSetupViewController {
            setupVC.finishedSetup()
        }
        if let replaceVC = navigationController as? PodReplacementNavigationController {
            replaceVC.completeSetup()
        }
    }
}
