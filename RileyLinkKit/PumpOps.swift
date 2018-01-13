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
            delegate.pumpOps(self, didChange: pumpState)
        }
    }

    private let sessionQueue = DispatchQueue(label: "com.rileylink.RileyLinkKit.PumpOps", qos: .utility)

    private unowned let delegate: PumpOpsDelegate
    
    public init(pumpSettings: PumpSettings, pumpState: PumpState?, delegate: PumpOpsDelegate) {
        self.pumpSettings = pumpSettings
        self.delegate = delegate

        if let pumpState = pumpState {
            self.pumpState = pumpState
        } else {
            self.pumpState = PumpState()
            self.delegate.pumpOps(self, didChange: self.pumpState)
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
            let semaphore = DispatchSemaphore(value: 0)

            deviceSelector { (device) in
                guard let device = device else {
                    block(nil)
                    semaphore.signal()
                    return
                }

                device.runSession(withName: name) { (session) in
                    block(PumpOpsSession(settings: self.pumpSettings, pumpState: self.pumpState, session: session, delegate: self))
                    semaphore.signal()
                }
            }

            semaphore.wait()
        }
    }

    public func runSession(withName name: String, using device: RileyLinkDevice, _ block: @escaping (_ session: PumpOpsSession) -> Void) {
        sessionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)

            device.runSession(withName: name) { (session) in
                block(PumpOpsSession(settings: self.pumpSettings, pumpState: self.pumpState, session: session, delegate: self))
                semaphore.signal()
            }

            semaphore.wait()
        }
    }
}


extension PumpOps: PumpOpsSessionDelegate {
    func pumpOpsSession(_ pumpOpsSynchronous: PumpOpsSession, didChange state: PumpState) {
        self.pumpState = state
    }
}
