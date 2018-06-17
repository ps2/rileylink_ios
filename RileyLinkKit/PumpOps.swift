//
//  PumpOps.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkBLEKit


public protocol PumpOpsDelegate: class {
    func pumpOps(_ pumpOps: PumpOps, didChange state: PumpState)
}


public class PumpOps {

    private var pumpSettings: PumpSettings

    private var pumpState: PumpState {
        didSet {
            delegate?.pumpOps(self, didChange: pumpState)
        }
    }

    private var configuredDevices: Set<RileyLinkDevice> = Set()

    private let sessionQueue = DispatchQueue(label: "com.rileylink.RileyLinkKit.PumpOps", qos: .utility)

    private weak var delegate: PumpOpsDelegate?
    
    public init(pumpSettings: PumpSettings, pumpState: PumpState?, delegate: PumpOpsDelegate?) {
        self.pumpSettings = pumpSettings
        self.delegate = delegate

        if let pumpState = pumpState {
            self.pumpState = pumpState
        } else {
            self.pumpState = PumpState()
            self.delegate?.pumpOps(self, didChange: self.pumpState)
        }
    }

    public func updateSettings(_ settings: PumpSettings) {
        sessionQueue.async {
            let oldSettings = self.pumpSettings
            self.pumpSettings = settings

            if oldSettings.pumpID != settings.pumpID {
                self.pumpState = PumpState()
            }
        }
    }

    public func runSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ session: PumpOpsSession?) -> Void) {
        sessionQueue.async {
            deviceSelector { (device) in
                guard let device = device else {
                    block(nil)
                    return
                }

                self.runSession(withName: name, using: device, block)
            }
        }
    }

    public func runSession(withName name: String, using device: RileyLinkDevice, _ block: @escaping (_ session: PumpOpsSession) -> Void) {
        sessionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)

            device.runSession(withName: name) { (session) in
                let session = PumpOpsSession(settings: self.pumpSettings, pumpState: self.pumpState, session: session, delegate: self)
                self.configureDevice(device, with: session)
                block(session)
                semaphore.signal()
            }

            semaphore.wait()
        }
    }

    // Must be called from within the RileyLinkDevice sessionQueue
    private func configureDevice(_ device: RileyLinkDevice, with session: PumpOpsSession) {
        guard !self.configuredDevices.contains(device) else {
            return
        }

        do {
            _ = try session.configureRadio(for: pumpSettings.pumpRegion)
        } catch {
            // Ignore the error and let the block run anyway
            return
        }

        NotificationCenter.default.post(name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceConnectionStateDidChange, object: device)
        configuredDevices.insert(device)
    }

    @objc private func deviceRadioConfigDidChange(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice else {
            return
        }

        NotificationCenter.default.removeObserver(self, name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.removeObserver(self, name: .DeviceConnectionStateDidChange, object: device)
        configuredDevices.remove(device)
    }
}


extension PumpOps: PumpOpsSessionDelegate {
    func pumpOpsSession(_ session: PumpOpsSession, didChange state: PumpState) {
        self.pumpState = state
    }
}
