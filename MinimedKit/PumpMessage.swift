//
//  PumpMessage.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/2/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation

public struct PumpMessage : CustomStringConvertible {
    public let packetType: PacketType
    public let address: Data
    public let messageType: MessageType
    public let messageBody: MessageBody

    public init(packetType: PacketType, address: String, messageType: MessageType, messageBody: MessageBody) {
        self.packetType = packetType
        self.address = Data(hexadecimalString: address)!
        self.messageType = messageType
        self.messageBody = messageBody
    }

    public init?(rxData: Data) {
        guard rxData.count >= 6,
            let packetType = PacketType(rawValue: rxData[0]), packetType != .meter,
            let messageType = MessageType(rawValue: rxData[4]),
            let messageBody = messageType.bodyType.init(rxData: rxData.subdata(in: 5..<rxData.count))
        else {
            return nil
        }

        self.packetType = packetType
        self.address = rxData.subdata(in: 1..<4)
        self.messageType = messageType
        self.messageBody = messageBody
    }

    public var txData: Data {
        var buffer = [UInt8]()

        buffer.append(packetType.rawValue)
        buffer += address[0..<3]
        buffer.append(messageType.rawValue)
        buffer.append(contentsOf: messageBody.txData)

        return Data(bytes: buffer)
    }
    
    public var description: String {
        return String(format: NSLocalizedString("PumpMessage(%1$@, %2$@, %3$@, %4$@)", comment: "The format string describing a pump message. (1: The packet type)(2: The message type)(3: The message address)(4: The message data"), String(describing: packetType), String(describing: messageType), String(describing: address), String(describing: self.messageBody.txData))
    }

}

