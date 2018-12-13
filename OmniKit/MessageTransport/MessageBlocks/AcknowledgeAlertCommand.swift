//
//  AcknowledgeAlertCommand.swift
//  OmniKit
//
//  Created by Eelke Jager on 18/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct AcknowledgeAlertCommand : NonceResyncableMessageBlock {
    
    
    public let blockType: MessageBlockType = .acknowledgeAlert
    public let length: UInt8 = 5
    public var nonce: UInt32
    public let alarms: PodAlarmState
    
    public init(nonce: UInt32, alarms: PodAlarmState) {
        self.nonce = nonce
        self.alarms = alarms
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        self.alarms = PodAlarmState(rawValue: encodedData[6])
    }
    
    public var data:  Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length
            ])
        data.appendBigEndian(nonce)
        data.append(alarms.rawValue)
        return data
    }
}
