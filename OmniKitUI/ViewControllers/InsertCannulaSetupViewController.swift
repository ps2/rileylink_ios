//
//  InsertCannulaSetupViewController.swift
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

class InsertCannulaSetupViewController: SetupTableViewController {
    
    var pumpManager: OmnipodPumpManager!
    
    // MARK: -
    
    @IBOutlet weak var activityIndicator: SetupIndicatorView!
    
    @IBOutlet weak var loadingLabel: UILabel!
    
    private var cancelErrorCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        continueState = .initial
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard continueState != .inserting else {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    
    private enum State {
        case initial
        case inserting
        case ready
    }
    
    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setConnectTitle()
            case .inserting:
                activityIndicator.state = .loading
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setConnectTitle()
                lastError = nil
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
                continueState = .initial
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return continueState == .ready
    }
    
    override func continueButtonPressed(_ sender: Any) {
        
        if case .ready = continueState {
            super.continueButtonPressed(sender)
        } else if case .initial = continueState {
            continueState = .inserting
            insertCannula()
        }
    }
    
    override func cancelButtonPressed(_ sender: Any) {
        let confirmVC = UIAlertController(pumpDeletionHandler: {
            self.pumpManager.deactivatePod() { (error) in
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
    }
    
    func insertCannula() {
        pumpManager.insertCannula() { (error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = error
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                    self.continueState = .ready
                }
            }
        }
    }
}

private extension SetupButton {
    func setConnectTitle() {
        setTitle(LocalizedString("Insert Cannula", comment: "Button title to insert cannula during setup"), for: .normal)
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

