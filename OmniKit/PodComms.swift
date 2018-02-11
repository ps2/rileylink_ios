//
//  PodComms.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/7/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit

public class PodComms {
    let podState: PodState
    
    private let sessionQueue = DispatchQueue(label: "com.rileylink.OmniKit.PodComms", qos: .utility)
    
    public init(podState: PodState) {
        self.podState = podState        
    }
    
    public func runSession(withName name: String, using device: RileyLinkDevice, _ block: @escaping (_ session: PodCommsSession) -> Void) {
        sessionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            
            device.runSession(withName: name) { (session) in
                block(PodCommsSession(podState: self.podState, session: session))
                semaphore.signal()
            }
            
            semaphore.wait()
        }
    }

}
