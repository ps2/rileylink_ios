//
//  PairPodSetupViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 9/18/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import RileyLinkKit
import OmniKit

class PairPodSetupViewController: SetupTableViewController {
    
    var rileyLinkPumpManager: RileyLinkPumpManager!
    
    var pumpManager: OmnipodPumpManager!
    
    private var cancelErrorCount = 0

    // MARK: -
    
    @IBOutlet weak var activityIndicator: SetupIndicatorView!
    
    @IBOutlet weak var loadingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        continueState = .initial
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard continueState != .pairing else {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    
    private enum State {
        case initial
        case pairing
        case paired
    }
    
    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setConnectTitle()
            case .pairing:
                activityIndicator.state = .loading
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setConnectTitle()
                lastError = nil
            case .paired:
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
            
            // If we changed the error text, update the continue state
            if !isHidden {
                continueState = .initial
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return continueState == .paired
    }
    
    override func continueButtonPressed(_ sender: Any) {
        
        if case .paired = continueState {
            super.continueButtonPressed(sender)
        } else if case .initial = continueState {
            if !pumpManager.hasPairedPod {
                continueState = .pairing
                pair()
            } else {
                configureAndPrimePod()
            }
        }
    }
    
    override func cancelButtonPressed(_ sender: Any) {
        if case .paired = continueState, let pumpManager = self.pumpManager {
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                pumpManager.deactivatePod() { (error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.cancelErrorCount += 1
                            self.lastError = error
                            if self.cancelErrorCount >= 2 {
                                super.cancelButtonPressed(sender)
                            }
                        } else {
                            super.cancelButtonPressed(sender)
                        }
                    }
                }
            })
            present(confirmVC, animated: true) {}
        } else {
            super.cancelButtonPressed(sender)
        }
    }
    
    func pair() {
        pumpManager.pair() { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error
                } else {
                    self.configureAndPrimePod()
                }
            }
        }
    }

    func configureAndPrimePod() {
        pumpManager.configureAndPrimePod { (error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = error
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(55)) {
                    self.finishPrime()
                }
            }
        }
    }
    
    func finishPrime() {
        pumpManager.finishPrime { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error
                } else {
                    self.continueState = .paired
                }
            }
        }
    }
}

private extension SetupButton {
    func setConnectTitle() {
        setTitle(LocalizedString("Pair", comment: "Button title to pair with pod during setup"), for: .normal)
    }
}

private extension UIAlertController {
    convenience init(pumpDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: LocalizedString("Are you sure you want to shutdown this pod?", comment: "Confirmation message for shutting down a pod"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: LocalizedString("Deactivate Pod", comment: "Button title to deactivate pod"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let exit = LocalizedString("Continue", comment: "The title of the continue action in an action sheet")
        addAction(UIAlertAction(title: exit, style: .default, handler: nil))
    }
}
