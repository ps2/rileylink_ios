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

    class func instantiateFromStoryboard(with pumpManager: OmnipodPumpManager) -> OmnipodPumpManagerSetupViewController {
        let vc = UIStoryboard(name: "OmnipodPumpManager", bundle: Bundle(for: OmnipodPumpManagerSetupViewController.self)).instantiateInitialViewController() as! OmnipodPumpManagerSetupViewController
        vc.pumpManager = pumpManager
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            vc.completeSetup()
        }
        return vc
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        navigationBar.shadowImage = UIImage()
        
        if let omnipodPairingViewController = topViewController as? PairPodSetupViewController, let rileyLinkPumpManager = rileyLinkPumpManager {
            omnipodPairingViewController.rileyLinkPumpManager = rileyLinkPumpManager
        }

        #if targetEnvironment(simulator)
        // If we're in the simulator, create a mock PodState
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            let fault: PodInfoFaultEvent?
            do {
                fault = try PodInfoFaultEvent(encodedData: Data(hexadecimalString: "02080100000a003800000003ff008700000095ff0000")!)
            } catch {
                fault = nil
            }
            let basalSchedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1.0, startTime: 0)])
            self.pumpManager = OmnipodPumpManager.jumpStartPod(address: 0x1f0b3557, lot: 40505, tid: 6439, schedule: basalSchedule, fault: fault)
            self.completeSetup()
        }
        #endif

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
            if let deviceProvider = rileyLinkPumpManager?.rileyLinkDeviceProvider, let basalSchedule = basalSchedule {
                let connectionManagerState = rileyLinkPumpManager?.rileyLinkConnectionManagerState
                let schedule = BasalSchedule(repeatingScheduleValues: basalSchedule.items)
                let pumpManagerState = OmnipodPumpManagerState(podState: nil, timeZone: .currentFixed, basalSchedule: schedule, rileyLinkConnectionManagerState: connectionManagerState)
                vc.pumpManager = OmnipodPumpManager(
                    state: pumpManagerState,
                    rileyLinkDeviceProvider: deviceProvider,
                    rileyLinkConnectionManager: rileyLinkPumpManager?.rileyLinkConnectionManager)
            }
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
