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

public class OmnipodPairingViewController: UIViewController, IdentifiableClass {
    
    private enum InteractionStates {
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
        
        var message: String {
            switch self {
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
    }
    
    public let podComms: PodComms
    public let device: RileyLinkDevice
    
    private var interactionState: InteractionStates = .noActivePod {
        didSet {
            
        }
    }
    
    @IBOutlet var progress: UIProgressView!
    @IBOutlet var stepInstructions: UITextView!
    @IBOutlet var titleLabel: UILabel!
    
    public init(podComms: PodComms, device: RileyLinkDevice) {
        self.podComms = podComms
        self.device = device
        if podComms.podIsActive {
            self.interactionState = .currentPodActive
        } else {
            self.interactionState = .noActivePod
        }
        
        super.init(nibName: OmnipodPairingViewController.className, bundle: Bundle(for: OmnipodPairingViewController.self))
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBAction func nextTapped(sender: UIButton) {
        switch interactionState {
        case .fillNewPod:
            initialPairing()
        default:
            stepInstructions.text = "not implemented yet..."
        }
    }
    
    @IBAction func cancelTapped(sender: UIButton) {
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }

    func initialPairing() {
        
        podComms.runSession(withName: "Pairing new pod", using: device) { (session) in
            do {
                try session.setupNewPOD()
            } catch let error {
                self.interactionState = .communicationError(during: "Address assignment", error: error)
            }
        }
    }
}

