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
    public let address: NSData
    public let messageType: MessageType
    public let messageBody: MessageBody

    public init(packetType: PacketType, address: String, messageType: MessageType, messageBody: MessageBody) {
        self.packetType = packetType
        self.address = NSData(hexadecimalString: address)!
        self.messageType = messageType
        self.messageBody = messageBody
    }

    public init?(rxData: NSData) {
        guard rxData.length >= 7,
            let packetType = PacketType(rawValue: rxData[0]) where packetType != .Meter,
            let messageType = MessageType(rawValue: rxData[4]),
                messageBody = messageType.bodyType.init(rxData: rxData.subdataWithRange(NSRange(5..<rxData.length - 1)))
        else {
            return nil
        }

        self.packetType = packetType
        self.address = rxData.subdataWithRange(NSRange(1...3))
        self.messageType = messageType
        self.messageBody = messageBody
    }

    public var txData: NSData {
        var buffer = [UInt8]()

        buffer.append(packetType.rawValue)
        buffer += address[0...2]
        buffer.append(messageType.rawValue)

        let data = NSMutableData(bytes: &buffer, length: buffer.count)

        data.appendData(messageBody.txData)

        return NSData(data: data)
    }
    
    public var description: String {
        return String(format: NSLocalizedString("PumpMessage(%1$@, %2$@, %3$@, %4$@)", comment: "The format string describing a pump message. (1: The packet type)(2: The message type)(3: The message address)(4: The message data"), String(self.packetType), String(self.messageType), self.address.hexadecimalString, self.messageBody.txData.hexadecimalString)
    }

}

