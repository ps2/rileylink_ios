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
    
    var pumpManager: OmnipodPumpManager! {
        didSet {
            if oldValue == nil && pumpManager != nil {
                pumpManagerWasSet()
            }
        }
    }
    
    private var cancelErrorCount = 0

    // MARK: -
    
    @IBOutlet weak var activityIndicator: SetupIndicatorView!
    
    @IBOutlet weak var loadingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueState = .initial
    }
    
    private func pumpManagerWasSet() {
        // Still priming?
        pumpManager.primeFinishesAt(completion: { (finishTime) in
            let currentTime = Date()
            if let finishTime = finishTime, finishTime > currentTime {
                self.continueState = .pairing
                let delay = finishTime.timeIntervalSince(currentTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.continueState = .ready
                }
            }
        })
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .pairing = continueState {
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    
    private enum State {
        case initial
        case pairing
        case priming(finishTime: Date)
        case ready
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
                loadingText = LocalizedString("Pairing...", comment: "The text of the loading label when pairing")
            case .priming(let finishTime):
                activityIndicator.state = .timedProgress(finishTime: finishTime)
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setConnectTitle()
                lastError = nil
                loadingText = LocalizedString("Priming...", comment: "The text of the loading label when priming")
            case .ready:
                activityIndicator.state = .completed
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
                lastError = nil
                loadingText = LocalizedString("Primed", comment: "The text of the loading label when pod is primed")
            }
        }
    }
    
    private var loadingText: String? {
        didSet {
            tableView.beginUpdates()
            loadingLabel.text = loadingText
            
            let isHidden = (loadingText == nil)
            loadingLabel.isHidden = isHidden
            tableView.endUpdates()
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
            
            loadingText = errorText
            
            // If we have an error, update the continue state
            if lastError != nil {
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
            pair()
        }
    }
    
    override func cancelButtonPressed(_ sender: Any) {
        if case .ready = continueState, let pumpManager = self.pumpManager {
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
        self.continueState = .pairing
        
        #if targetEnvironment(simulator)
        // If we're in the simulator, create a mock PodState
        let mockDelay = TimeInterval(seconds: 5)
        DispatchQueue.main.asyncAfter(deadline: .now() + mockDelay) {
            let finishTime = Date() + mockDelay
            self.continueState = .priming(finishTime: finishTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + mockDelay) {
                self.pumpManager.jumpStartPod(address: 0x1f0b3557, lot: 40505, tid: 6439, mockFault: true)
                self.continueState = .ready
            }
        }
        #else

        pumpManager.pairAndPrime() { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let finishTime):
                    self.continueState = .priming(finishTime: finishTime)
                    let delay = finishTime.timeIntervalSinceNow
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.continueState = .ready
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
