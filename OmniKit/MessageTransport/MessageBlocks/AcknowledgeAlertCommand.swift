//
//  AcknowledgeAlertCommand.swift
//  OmniKit
//
//  Created by Eelke Jager on 18/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

//
//  GetStatusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct AcknowledgeAlertCommand : MessageBlock {
    
    
    public let blockType: MessageBlockType = .acknowledgeAlert
    public let length: UInt8 = 5
    public var nonce: UInt32
    public let beepType: ConfigureAlertsCommand.BeepType
    
    public init(nonce: UInt32, beepType: ConfigureAlertsCommand.BeepType) {
        self.nonce = nonce
        self.beepType = beepType
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        guard ConfigureAlertsCommand.BeepType(rawValue: encodedData[6] >> 2) != nil else {
            throw MessageError.unknownValue(value: 1 >> encodedData[6], typeDescription: "BeepType")
        }
        self.beepType = ConfigureAlertsCommand.BeepType(rawValue: encodedData[6] >> 2)!
    }
    
    public var data:  Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length
            ])
        data.appendBigEndian(nonce)
        data.append(UInt8(1<<beepType.rawValue))
        return data
    }
}
