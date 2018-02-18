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
        case pleaseWaitForActivePod
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
            default:
                return "Not implemented yet."
            }
        }
        
        var okButtonText: String? {
            switch self {
            case .noActivePod:
                return NSLocalizedString("Yes", comment: "Affirmatitve response to question")
            case .fillNewPod:
                return NSLocalizedString("Next", comment: "Button text for next action")
            default:
                return nil
            }
        }

        var cancelButtonText: String? {
            switch self {
            case .noActivePod:
                return NSLocalizedString("No", comment: "Negative response to question")
            case .fillNewPod:
                return NSLocalizedString("Cancel", comment: "Button text to cancel")
            default:
                return nil
            }
        }
        
        var progress: Float? {
            switch self {
            case .noActivePod:
                return 0.1
            case .fillNewPod:
                return 0.2
            case .priming:
                return 0.4
            case .prepareSite:
                return 0.6
            case .removeBacking:
                return 0.8
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
        }
    }
    
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var stepInstructions: UITextView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var okButton: UIButton!
    @IBOutlet var cancelButton: UIButton!

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
            initialPairing()
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

    func initialPairing() {
        
        podComms.runSession(withName: "Pairing new pod", using: device) { (session) in
            do {
                try session.setupNewPOD()
                DispatchQueue.main.async {
                    self.interactionState = .priming
                }
            } catch let error {
                DispatchQueue.main.async {
                    self.interactionState = .communicationError(during: "Address assignment", error: error)
                }
            }
        }
    }
}

