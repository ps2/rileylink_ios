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
        if case .startingInsertion = continueState {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    
    private enum State {
        case initial
        case startingInsertion
        case inserting(finishTime: Date)
        case ready
    }
    
    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setConnectTitle()
            case .startingInsertion:
                activityIndicator.state = .loading
                footerView.primaryButton.isEnabled = false
                lastError = nil
            case .inserting(let finishTime):
                activityIndicator.state = .timedProgress(finishTime: finishTime)
                footerView.primaryButton.isEnabled = false
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
        if case .ready = continueState {
            return true
        } else {
            return false
        }
    }
    
    override func continueButtonPressed(_ sender: Any) {
        
        if case .ready = continueState {
            super.continueButtonPressed(sender)
        } else if case .initial = continueState {
            continueState = .startingInsertion
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
        #if targetEnvironment(simulator)
        let mockDelay = TimeInterval(seconds: 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + mockDelay) {
            let finishTime = Date() + mockDelay
            self.continueState = .inserting(finishTime: finishTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + mockDelay) {
                self.continueState = .ready
            }
        }
        #else
        pumpManager.insertCannula() { (result) in
            DispatchQueue.main.async {
                switch(result) {
                case .success(let finishTime):
                    self.continueState = .inserting(finishTime: finishTime)
                    let delay = finishTime.timeIntervalSinceNow
                    if delay > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                            self.continueState = .ready
                        }
                    }
                case .failure(let error):
                    self.lastError = error
                }
            }
        }
        #endif
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

