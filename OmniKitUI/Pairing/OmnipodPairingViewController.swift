//
//  OmnipodPairingViewController.swift
//  RileyLinkKitUI
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import OmniKit
import RileyLinkBLEKit
import RileyLinkKit
import LoopKitUI

// Implementing flow as described here: https://app.moqups.com/pheltzel@gmail.com/GNBaAhrB1y/view/page/aa9df7b72

public class OmnipodPairingViewController: UIViewController, IdentifiableClass {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUIForState()
    }
    
    open var setupViewController: PumpManagerSetupViewController? {
        return navigationController as? PumpManagerSetupViewController
    }
    
    var rileyLinkPumpManager: RileyLinkPumpManager!
    
    var podComms: PodComms?
    var podState: PodState?
    
    var pumpManagerState: OmnipodPumpManagerState? {
        get {
            guard let podState = podState else {
                    return nil
            }
            
            return OmnipodPumpManagerState(
                podState: podState,
                rileyLinkConnectionManagerState: self.rileyLinkPumpManager.rileyLinkConnectionManagerState
            )
        }
    }

    var pumpManager: OmnipodPumpManager? {
        guard let pumpManagerState = pumpManagerState else {
            return nil
        }
        
        return OmnipodPumpManager(
            state: pumpManagerState,
            rileyLinkDeviceProvider: rileyLinkPumpManager.rileyLinkDeviceProvider,
            rileyLinkConnectionManager: rileyLinkPumpManager.rileyLinkConnectionManager)
    }

    
    private enum InteractionState {
        case initial
        case fillNewPod
        case communicationError(during: String, error: Error)
        case priming
        case prepareSite
        case communicationSuccessful
        case communicationTimeout
        case discard
        case pleaseWaitForDeactivation
        case removeBacking
        case insertCannula
        case insertingCannula
        case checkInfusionSite
        
        var instructions: String {
            switch self {
            case .initial:
                return NSLocalizedString("No active pod. Activate one now?", comment: "Message for no active pod.")
            case .fillNewPod:
                return NSLocalizedString("Fill a new pod with insulin.\n\nAfter filling pod, listen for 2 beeps, then press \"Next.\"\n\nNOTE: Do not remove needle cap at this time.", comment: "Message for fill new pod screen")
            case .communicationError(let action, let error):
                return String(format: NSLocalizedString("Error occurred while %1$@: %2$@", comment: "The format string description of a communication error. (1: the action during which the error occurred) (2: The error that occurred"), action, String(describing: error))
            case .priming:
                return NSLocalizedString("Priming...", comment: "Message shown while priming pod")
            case .prepareSite:
                return NSLocalizedString("Prepare site. Remove pod's needle cap.  If cannula sticks out, press Discard", comment: "Message for prepare site screen")
            case .removeBacking:
                return NSLocalizedString("Remove pod's adhesive backing. If pod is wet or dirty, or adhesive is folded, press Discard. If pod OK, apply to site", comment: "Message for remove pod adhesive backing screen")
            case .insertCannula:
                return NSLocalizedString("Press Start to insert cannula and begin basal delivery.", comment: "Message for screen prepping user for cannula insertion")
            case .insertingCannula:
                return NSLocalizedString("Inserting cannula...", comment: "Message shown during cannula insertion")
            case .checkInfusionSite:
                return NSLocalizedString("Current basal is programmed. Check infusion site and cannula. Is cannula inserted properly?", comment: "Message for check infusion site screen")
            default:
                return "Not implemented yet."
            }
        }
        
        var okButtonText: String? {
            switch self {
            case .initial, .checkInfusionSite:
                return NSLocalizedString("Yes", comment: "Affirmative response to question")
            case .fillNewPod, .prepareSite, .removeBacking:
                return NSLocalizedString("Next", comment: "Button text for next action")
            case .insertCannula:
                return NSLocalizedString("Start", comment: "Button text for start action")
            default:
                return nil
            }
        }

        var cancelButtonText: String? {
            switch self {
            case .initial, .checkInfusionSite:
                return NSLocalizedString("No", comment: "Negative response to question")
            case .fillNewPod:
                return NSLocalizedString("Cancel", comment: "Button text to cancel")
            case .prepareSite, .removeBacking, .insertCannula:
                return NSLocalizedString("Discard", comment: "Button text to discard")
            default:
                return nil
            }
        }
        
        var showActivity: Bool {
            switch self {
            case .priming, .insertingCannula:
                return true
            default:
                return false
            }
        }
        
        var progress: Float? {
            switch self {
            case .fillNewPod:
                return 0.1
            case .priming:
                return 0.3
            case .prepareSite:
                return 0.5
            case .removeBacking:
                return 0.7
            case .insertCannula:
                return 0.9
            case .checkInfusionSite:
                return 1
            default:
                return nil
            }
        }
    }
    
    private var interactionState: InteractionState = .initial {
        didSet {
            updateUIForState()
        }
    }
    
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var stepInstructions: UITextView!
    @IBOutlet var okButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    @IBAction func nextTapped(sender: UIButton) {
        switch interactionState {
        case .initial:
            interactionState = .fillNewPod
        case .fillNewPod:
            pair()
        case .prepareSite:
            interactionState = .removeBacking
        case .removeBacking:
            interactionState = .insertCannula
        case .insertCannula:
            interactionState = .insertingCannula
            insertCannula()
        case .checkInfusionSite:
            if let setupViewController = setupViewController as? OmnipodPumpManagerSetupViewController {
                setupViewController.completeSetup()
            }
            //_ = navigationController?.popViewController(animated: true)
        default:
            stepInstructions.text = "\"\(String(describing: sender.title(for: .normal)))\" not handled for state \(String(describing: interactionState))"
        }
    }
    
    @IBAction func cancelTapped(sender: UIButton) {
        switch interactionState {
        default:
            stepInstructions.text = "\"\(String(describing: sender.title(for: .normal)))\" not handled for state \(String(describing: interactionState))"
        }
    }
    
    func updateUIForState() {
        stepInstructions.text = interactionState.instructions
        if let okText = interactionState.okButtonText {
            okButton.setTitle(okText, for: .normal)
            okButton.isHidden = false
        } else {
            okButton.isHidden = true
        }
        if let cancelText = interactionState.cancelButtonText {
            cancelButton.setTitle(cancelText, for: .normal)
            cancelButton.isHidden = false
        } else {
            cancelButton.isHidden = true
        }
        if let progress = interactionState.progress {
            progressView.isHidden = false
            progressView.progress = progress
        } else {
            progressView.isHidden = true
        }
        if interactionState.showActivity {
            self.activityIndicator.startAnimating()
        } else {
            self.activityIndicator.stopAnimating()
        }
    }
    
    func pair() {
        self.interactionState = .priming
        
        guard podComms == nil else {
            return
        }
        
        let deviceSelector = rileyLinkPumpManager.rileyLinkDeviceProvider.firstConnectedDevice
        
        // TODO: Let user choose between current and previously used timezone?
        PodComms.pair(using: deviceSelector, timeZone: .currentFixed, completion: { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let podState):
                    self.podState = podState
                    self.podComms = PodComms(podState: podState, delegate: self)
                    self.configurePod()
                case .failure(let error):
                    self.interactionState = .communicationError(during: "Pairing", error: error)
                }
            }
            
        })
    }
    
    func configurePod() {
        guard let podComms = podComms else {
            return
        }

        let deviceSelector = rileyLinkPumpManager.rileyLinkDeviceProvider.firstConnectedDevice

        podComms.runSession(withName: "Configure pod", using: deviceSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.configurePod()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(55)) {
                        self.interactionState = .prepareSite
                        self.finishPrime()
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.interactionState = .communicationError(during: "Address assignment", error: error)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Configuration", error: error)
                }
            }
        }
    }
    
    func finishPrime() {
        guard let podComms = podComms else {
            return
        }
        
        let deviceSelector = rileyLinkPumpManager.rileyLinkDeviceProvider.firstConnectedDevice

        podComms.runSession(withName: "Finish Prime", using: deviceSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.finishPrime()
                } catch let error {
                    DispatchQueue.main.async {
                        self.interactionState = .communicationError(during: "Finish Prime", error: error)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Finishing Prime", error: error)
                }
            }
        }
    }

    func insertCannula() {
        
        guard let podState = podState, let podComms = podComms else {
            return
        }
        
        let deviceSelector = rileyLinkPumpManager.rileyLinkDeviceProvider.firstConnectedDevice

        podComms.runSession(withName: "Insert cannula", using: deviceSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    // TODO: Need to get schedule from PumpManagerDelegate
                    let scheduleOffset = podState.timeZone.scheduleOffset(forDate: Date())
                    try session.insertCannula(basalSchedule: temporaryBasalSchedule, scheduleOffset: scheduleOffset)
                    DispatchQueue.main.async {
                        self.interactionState = .checkInfusionSite
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.interactionState = .communicationError(during: "Cannula insertion", error: error)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Finishing Prime", error: error)
                }
            }
        }
    }
}

extension OmnipodPairingViewController: PodCommsDelegate {
    public func podComms(_ podComms: PodComms, didChange state: PodState) {
        self.podState = state
    }
}

