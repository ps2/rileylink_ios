//
//  PodState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class PodState {
    let address: UInt32
    let nonceState: NonceState
    var packetNumber: Int
    var messageNumber: Int
    
    public init(address: UInt32, nonceState: NonceState, packetNumber: Int, messageNumber: Int) {
        self.address = address
        self.nonceState = nonceState
        self.packetNumber = packetNumber
        self.messageNumber = messageNumber
    }
    
    func incrementPacketNumber() {
        packetNumber = (packetNumber + 1) & 0b11111
    }
    
    func incrementMessageNumber() {
        messageNumber = (messageNumber + 1) & 0b1111
    }
}
