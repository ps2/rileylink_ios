//
//  PodComms.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/7/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit

public protocol PodCommsDelegate: class {
    func podComms(_ podComms: PodComms, didChange state: PodState)
}

public class PodComms {
   

    public private(set) var podState: PodState {
        didSet {
            if let delegate = delegate {
                delegate.podComms(self, didChange: podState)
            }
        }
    }
    
    private var configuredDevices: Set<RileyLinkDevice> = Set()
    
    public var podIsActive: Bool {
        return podState.isActive
    }
    
    public weak var delegate: PodCommsDelegate?

    private let sessionQueue = DispatchQueue(label: "com.rileylink.OmniKit.PodComms", qos: .utility)
    
    public init(podState: PodState) {
        self.podState = podState
    }
    
    public func runSession(withName name: String, using device: RileyLinkDevice, _ block: @escaping (_ session: PodCommsSession) -> Void) {
        sessionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            
            device.runSession(withName: name) { (commandSession) in
                let podSession = PodCommsSession(podState: self.podState, session: commandSession, device: device, delegate: self)
                self.configureDevice(device, with: podSession)
                block(podSession)
                semaphore.signal()
            }
            
            semaphore.wait()
        }
    }
    
    // Must be called from within the RileyLinkDevice sessionQueue
    private func configureDevice(_ device: RileyLinkDevice, with session: PodCommsSession) {
        guard !self.configuredDevices.contains(device) else {
            return
        }
        
        do {
            _ = try session.configureRadio()
        } catch {
            // Ignore the error and let the block run anyway
            return
        }
        
        NotificationCenter.default.post(name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceRadioConfigDidChange, object: device)
        configuredDevices.insert(device)
    }

    @objc private func deviceRadioConfigDidChange(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice else {
            return
        }
        
        NotificationCenter.default.removeObserver(self, name: .DeviceRadioConfigDidChange, object: device)
        configuredDevices.remove(device)
    }

}


extension PodComms: PodCommsSessionDelegate {
    public func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState) {
        self.podState = state
    }
}
