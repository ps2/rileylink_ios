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
    
    var pumpManager: OmnipodPumpManager!
    
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
                activityIndicator.state = .loading
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setDeactivateTitle()
                lastError = nil
            case .deactivationFailed:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
            case .ready:
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
                continueState = .deactivationFailed
            }
            
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return continueState == .ready || continueState == .deactivationFailed
    }
    
    override func continueButtonPressed(_ sender: Any) {
        switch continueState {
        case .ready, .deactivationFailed:
            pumpManager.forgetPod()
            super.continueButtonPressed(sender)
        case .initial:
            continueState = .deactivating
            deactivate()
        case .deactivating:
            break
        }
    }
    
    func deactivate() {
        
        pumpManager.deactivatePod { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error
                } else {
                    self.continueState = .ready
                }
            }
        }
    }
}

private extension SetupButton {
    func setDeactivateTitle() {
        setTitle(LocalizedString("Deactivate Pod", comment: "Button title for pod deactivation"), for: .normal)
    }
}
