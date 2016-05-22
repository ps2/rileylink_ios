//
//  MySentryAckMessageBody.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/4/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// Describes an ACK message sent by a MySentry device in response to pump status messages.
/// a2 350535 06 59 000695 00 04 00 00 00 e2
public struct MySentryAckMessageBody: MessageBody {
    public static let length = 9

    let sequence: UInt8
    let mySentryID: NSData
    let responseMessageTypes: [MessageType]

    public init?(sequence: UInt8, watchdogID: NSData, responseMessageTypes: [MessageType]) {
        guard responseMessageTypes.count <= 4 && watchdogID.length == 3 else {
            return nil
        }

        self.sequence = sequence
        self.mySentryID = watchdogID
        self.responseMessageTypes = responseMessageTypes
    }

    public init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            return nil
        }

        sequence = rxData[0]
        mySentryID = rxData[1...3]
        responseMessageTypes = rxData[5...8].flatMap({ MessageType(rawValue: $0) })
    }

    public var txData: NSData {
        var buffer = self.dynamicType.emptyBuffer

        buffer[0] = sequence
        buffer.replaceRange(1...3, with: mySentryID[0...2])

        buffer.replaceRange(5..<5 + responseMessageTypes.count, with: responseMessageTypes.map({ $0.rawValue }))

        return NSData(bytes: &buffer, length: buffer.count)
    }
}
