//
//  MinimedPumpSetupViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MinimedKit
import RileyLinkBLEKit
import RileyLinkKit
import RileyLinkKitUI


public class MinimedPumpManagerSetupViewController: RileyLinkManagerSetupViewController {

    class func instantiateFromStoryboard() -> MinimedPumpManagerSetupViewController {
        return UIStoryboard(name: "MinimedPumpManager", bundle: Bundle(for: MinimedPumpManagerSetupViewController.self)).instantiateInitialViewController() as! MinimedPumpManagerSetupViewController
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        navigationBar.shadowImage = UIImage()
    }

    private(set) var pumpManager: MinimedPumpManager?

    /*
     1. RileyLink
     - RileyLinkPumpManagerState

     2. Pump
     - PumpSettings
     - PumpColor
     -- Submit --
     - PumpOps
     - PumpState

     3. (Optional) Connect Devices

     4. Time

     5. Basal Rates & Delivery Limits

     6. Pump Setup Complete
     */

    override public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)

        // Read state values
        let viewControllers = navigationController.viewControllers
        let count = navigationController.viewControllers.count

        if count >= 2 {
            switch viewControllers[count - 2] {
            case let vc as MinimedPumpIDSetupViewController:
                pumpManager = vc.pumpManager
                maxBasalRateUnitsPerHour = vc.maxBasalRateUnitsPerHour
                maxBolusUnits = vc.maxBolusUnits
                basalSchedule = vc.basalSchedule
            default:
                break
            }
        }

        // Set state values
        switch viewController {
        case let vc as MinimedPumpIDSetupViewController:
            vc.rileyLinkPumpManager = rileyLinkPumpManager
        case let vc as MinimedPumpSentrySetupViewController:
            vc.pumpManager = pumpManager
        case is MinimedPumpClockSetupViewController:
            break
        case let vc as MinimedPumpSettingsSetupViewController:
            vc.pumpManager = pumpManager
        case let vc as MinimedPumpSetupCompleteViewController:
            vc.pumpImage = pumpManager?.state.largePumpImage
        default:
            break
        }

        // Adjust the appearance for the main setup view controllers only
        if viewController is SetupTableViewController {
            navigationBar.isTranslucent = false
            navigationBar.shadowImage = UIImage()
        } else {
            navigationBar.isTranslucent = true
            navigationBar.shadowImage = nil
            viewController.navigationItem.largeTitleDisplayMode = .never
        }
    }

    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {

        // Adjust the appearance for the main setup view controllers only
        if viewController is SetupTableViewController {
            navigationBar.isTranslucent = false
            navigationBar.shadowImage = UIImage()
        } else {
            navigationBar.isTranslucent = true
            navigationBar.shadowImage = nil
        }
    }

    func completeSetup() {
        if let pumpManager = pumpManager {
            setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
        }
    }
}
