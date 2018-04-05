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

// Implementing flow as described here: https://app.moqups.com/pheltzel@gmail.com/GNBaAhrB1y/view/page/aa9df7b72

public class OmnipodPairingViewController: UIViewController, IdentifiableClass {
    
    private enum InteractionState {
        case initial
        case currentPodActive
        case noActivePod
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
        case checkInfusionSite
        
        var instructions: String {
            switch self {
            case .noActivePod:
                return NSLocalizedString("No active pod. Activate one now?", comment: "Message for no active pod.")
            case .fillNewPod:
                return NSLocalizedString("Fill a new pod with insulin.\n\nAfter filling pod, listen for 2 beeps, then press \"Next.\"\n\nNOTE: Do not remove needle cap at this time.", comment: "Message for fill new pod screen")
            case .communicationError(let action, let error):
                return String(format: NSLocalizedString("Error occurred while %1$@: %2$@", comment: "The format string description of a communication error. (1: the action during which the error occurred) (2: The error that occurred"), action, String(describing: error))
            case .priming:
                return NSLocalizedString("Priming...", comment: "Message for priming screen")
            case .prepareSite:
                return NSLocalizedString("Prepare site. Remove pod's needle cap.  If cannula sticks out, press Discard", comment: "Message for prepare site screen")
            case .removeBacking:
                return NSLocalizedString("Remove pod's adhesive backing. If pod is wet or dirty, or adhesive is folded, press Discard. If pod OK, apply to site", comment: "Message for remove pod adhesive backing screen")
            case .insertCannula:
                return NSLocalizedString("Press Start to insert cannula and begin basal delivery.", comment: "Message for screen prepping user for cannula insertion")
            case .checkInfusionSite:
                return NSLocalizedString("Current basal is programmed. Check infusion site and cannula. Is cannula inserted properly?", comment: "Message for check infusion site screen")
            default:
                return "Not implemented yet."
            }
        }
        
        var okButtonText: String? {
            switch self {
            case .noActivePod, .checkInfusionSite:
                return NSLocalizedString("Yes", comment: "Affirmative response to question")
            case .fillNewPod, .prepareSite, .removeBacking, .insertCannula:
                return NSLocalizedString("Next", comment: "Button text for next action")
            default:
                return nil
            }
        }

        var cancelButtonText: String? {
            switch self {
            case .noActivePod, .checkInfusionSite:
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
            case .priming:
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
    
    public let podComms: PodComms
    public let device: RileyLinkDevice
    
    private var interactionState: InteractionState = .noActivePod {
        didSet {
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
    }
    
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var stepInstructions: UITextView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var okButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!


    public init(podComms: PodComms, device: RileyLinkDevice) {
        self.podComms = podComms
        self.device = device
        self.interactionState = .initial
        
        super.init(nibName: OmnipodPairingViewController.className, bundle: Bundle(for: OmnipodPairingViewController.self))
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBAction func nextTapped(sender: UIButton) {
        switch interactionState {
        case .noActivePod:
            interactionState = .fillNewPod
        case .fillNewPod:
            pair()
        case .prepareSite:
            interactionState = .removeBacking
        case .removeBacking:
            interactionState = .insertCannula
        case .insertCannula:
            insertCannula()
        case .checkInfusionSite:
            _ = navigationController?.popViewController(animated: true)
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
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if podComms.podIsActive {
            self.interactionState = .currentPodActive
        } else {
            self.interactionState = .noActivePod
        }
    }

    func pair() {
        
        self.interactionState = .priming
        
        podComms.runSession(withName: "Pairing new pod", using: device) { (session) in
            do {

                // TODO: Let user choose between current and previously used timezone?
                try session.setupNewPOD(timeZone: .currentFixed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(55)) {
                    self.interactionState = .prepareSite
                    self.finishPrime()
                }
            } catch let error {
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Address assignment", error: error)
                }
            }
        }
    }
    
    func finishPrime() {
        podComms.runSession(withName: "Finish Prime", using: device) { (session) in
            do {
                try session.finishPrime()
            } catch let error {
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Finish Prime", error: error)
                }
            }
        }
    }

    func insertCannula() {
        
        podComms.runSession(withName: "Insert cannula", using: device) { (session) in
            do {
                guard let podState = self.podComms.podState else {
                    fatalError("insertCannula with no podState")
                }
                let entry = BasalScheduleEntry(rate: 0.05, duration: .hours(24))
                let schedule = BasalSchedule(entries: [entry])
                var calendar = Calendar.current
                calendar.timeZone = podState.timeZone
                let now = Date()
                let components = calendar.dateComponents([.day , .month, .year], from: now)
                guard let startOfSchedule = calendar.date(from: components) else {
                    fatalError("invalid date")
                }
                let scheduleOffset = now.timeIntervalSince(startOfSchedule)
                try session.insertCannula(basalSchedule: schedule, scheduleOffset: scheduleOffset)
                DispatchQueue.main.async {
                    self.interactionState = .checkInfusionSite
                }
            } catch let error {
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Cannula insertion", error: error)
                }
            }
        }
    }

    
}

