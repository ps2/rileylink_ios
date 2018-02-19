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
            
            device.runSession(withName: name) { (session) in
                block(PodCommsSession(podState: self.podState, session: session, device: device, delegate: self))
                semaphore.signal()
            }
            
            semaphore.wait()
        }
    }    
}


extension PodComms: PodCommsSessionDelegate {
    public func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState) {
        self.podState = state
    }
}
