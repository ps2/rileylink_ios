//
//  ReplacePodViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 11/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKitUI
import OmniKit


class ReplacePodViewController: SetupTableViewController {

    enum PodReplacementReason {
        case normal
        case fault(_ faultCode: FaultEventCode)
        case canceledPairingBeforeApplication
        case canceledPairing
    }

    var replacementReason: PodReplacementReason = .normal {
        didSet {
            switch replacementReason {
            case .normal:
                    break // Text set in interface builder
            case .fault(let faultCode):
                switch faultCode.rawValue {
                case 0x18:
                    instructionsLabel.text = LocalizedString("Empty reservoir. Insulin delivery has stopped. Please deactivate and remove pod.", comment: "Instructions when replacing pod due to an empty reservoir")
                case 0x1C:
                    instructionsLabel.text = LocalizedString("Pod expired. Insulin delivery has stopped. Please deactivate and remove pod.", comment: "Instructions when replacing pod due to an expired pod")
                case 0x14, 0x5A, 0x60, 0x61, 0x62, 0x66, 0x67, 0x68, 0x69, 0x6A:
                        instructionsLabel.text = LocalizedString("Occlusion detected. Insulin delivery has stopped. Please deactivate and remove pod.", comment: "Instructions when replacing pod due to an occlusion")
                default:
                    instructionsLabel.text = String(format: LocalizedString("The pod has detected internal fault %d. Insulin delivery has stopped. Please deactivate and remove pod.", comment: "Instructions when replacing pod due to a fault (1: The fault code value)"), faultCode.rawValue)
                }
            case .canceledPairingBeforeApplication:
                instructionsLabel.text = LocalizedString("Incompletely set up pod must be deactivated before pairing with a new one. Please deactivate and discard pod.", comment: "Instructions when deactivating pod that has been paired, but not attached.")
            case .canceledPairing:
                instructionsLabel.text = LocalizedString("Incompletely set up pod must be deactivated before pairing with a new one. Please deactivate and remove pod.", comment: "Instructions when deactivating pod that has been paired and possibly attached.")
            }

            tableView.reloadData()
        }
    }
    
    var pumpManager: OmnipodPumpManager! {
        didSet {
            pumpManager.getPodState { (podState) in
                DispatchQueue.main.async {
                    if let podFault = podState?.fault {
                        self.replacementReason = .fault(podFault.currentStatus)
                    } else if podState?.setupProgress.primingNeeded == true {
                        self.replacementReason = .canceledPairingBeforeApplication
                    } else if podState?.setupProgress.needsCannulaInsertion == true {
                        self.replacementReason = .canceledPairing
                    } else {
                        self.replacementReason = .normal
                    }
                }
            }
        }
    }
    
    // MARK: -
    
    @IBOutlet weak var activityIndicator: SetupIndicatorView!
    
    @IBOutlet weak var loadingLabel: UILabel!

    @IBOutlet weak var instructionsLabel: UILabel!


    private var tryCount: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        continueState = .initial
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard continueState != .deactivating else {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    // MARK: - Navigation
    
    private enum State {
        case initial
        case deactivating
        case deactivationFailed
        case continueAfterFailure
        case ready
    }
    
    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setDeactivateTitle()
            case .deactivating:
                activityIndicator.state = .indeterminantProgress
                footerView.primaryButton.isEnabled = false
                lastError = nil
            case .deactivationFailed:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setRetryTitle()
            case .continueAfterFailure:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
                tableView.beginUpdates()
                loadingLabel.text = LocalizedString("Unable to deactivate pod. Please continue and pair a new one.", comment: "Instructions when pod cannot be deactivated")
                loadingLabel.isHidden = false
                tableView.endUpdates()
            case .ready:
                navigationItem.rightBarButtonItem = nil
                activityIndicator.state = .completed
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
                lastError = nil
            }
        }
    }
    
    private var lastError: Error? {
        didSet {
            guard oldValue != nil || lastError != nil else {
                return
            }
            
            var errorText = lastError?.localizedDescription
            
            if let error = lastError as? LocalizedError {
                let localizedText = [error.errorDescription, error.failureReason, error.recoverySuggestion].compactMap({ $0 }).joined(separator: ". ") + "."
                
                if !localizedText.isEmpty {
                    errorText = localizedText
                }
            }
            
            tableView.beginUpdates()
            loadingLabel.text = errorText
            
            let isHidden = (errorText == nil)
            loadingLabel.isHidden = isHidden
            tableView.endUpdates()
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return continueState == .ready || continueState == .continueAfterFailure
    }
    
    override func continueButtonPressed(_ sender: Any) {
        switch continueState {
        case .ready, .continueAfterFailure:
            super.continueButtonPressed(sender)
        case .initial, .deactivationFailed:
            continueState = .deactivating
            deactivate()
        case .deactivating:
            break
        }
    }
    
    func deactivate() {
        tryCount += 1
        
        pumpManager.deactivatePod { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    if self.tryCount > 1 {
                        self.pumpManager.forgetPod()
                        self.continueState = .continueAfterFailure
                    } else {
                        self.lastError = error
                        self.continueState = .deactivationFailed
                    }
                } else {
                    self.pumpManager.forgetPod()
                    self.continueState = .ready
                }
            }
        }
    }

    override func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

}

private extension SetupButton {
    func setDeactivateTitle() {
        setTitle(LocalizedString("Deactivate Pod", comment: "Button title for pod deactivation"), for: .normal)
    }
    
    func setRetryTitle() {
        setTitle(LocalizedString("Retry Pod Deactivation", comment: "Button title for retrying pod deactivation"), for: .normal)
    }
}


