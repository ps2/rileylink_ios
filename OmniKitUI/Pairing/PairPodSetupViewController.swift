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
    
    private var podComms: PodComms?
    
    private var podState: PodState?
    
    private var cancelErrorCount = 0
    
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
            if podState == nil {
                continueState = .pairing
                pair()
            } else {
                configurePod()
            }
        }
    }
    
    override func cancelButtonPressed(_ sender: Any) {
        if case .paired = continueState, let pumpManager = self.pumpManager {
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                let deviceSelector = pumpManager.rileyLinkDeviceProvider.firstConnectedDevice
                pumpManager.podComms.runSession(withName: "Deactivate Pod", using: deviceSelector, { (result) in
                    do {
                        switch result {
                        case .success(let session):
                            let _ = try session.changePod()
                            DispatchQueue.main.async {
                                super.cancelButtonPressed(sender)
                            }
                        case.failure(let error):
                            throw error
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            self.cancelErrorCount += 1
                            self.lastError = error
                            if self.cancelErrorCount >= 2 {
                                super.cancelButtonPressed(sender)
                            }
                        }
                    }
                })
            })
            present(confirmVC, animated: true) {}
        } else {
            super.cancelButtonPressed(sender)
        }
    }
    
    func pair() {
        
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
                    self.lastError = error
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
                        self.finishPrime()
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.lastError = error
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.lastError = error
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
                    DispatchQueue.main.async {
                        self.continueState = .paired
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.lastError = error
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.lastError = error
                }
            }
        }
    }


}

extension PairPodSetupViewController: PodCommsDelegate {
    public func podComms(_ podComms: PodComms, didChange state: PodState) {
        self.podState = state
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
            message: NSLocalizedString("Are you sure you want to shutdown this pod?", comment: "Confirmation message for shutting down a pod"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Deactivate Pod", comment: "Button title to deactivate pod"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let exit = NSLocalizedString("Continue", comment: "The title of the continue action in an action sheet")
        addAction(UIAlertAction(title: exit, style: .default, handler: nil))
    }
}
