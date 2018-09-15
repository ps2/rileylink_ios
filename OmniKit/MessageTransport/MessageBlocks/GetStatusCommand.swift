//
//  GetStatusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct GetStatusCommand : MessageBlock {
    
    public enum StatusType: UInt8 {
        case normal = 0x00
        case configuredAlerts = 0x01
        case faultEvents = 0x02
        case dataLog = 0x03
        case faultDataInitializationTime = 0x04
        case hardcodedValues = 0x06
        case resetStatus = 0x46 // including state, initialization time, any faults
        case dumpRecentFlashLog = 0x50
        case dumpOlderFlashlog  = 0x51 // but dumps entries before the last 50
        // https://github.com/openaps/openomni/wiki/Command-0E-Status-Request
    }
    
    public let blockType: MessageBlockType = .getStatus
    public let length: UInt8 = 1
    public let requestType: StatusType
    
    public init(requestType: StatusType = .normal) {
        self.requestType = requestType
    }
    
     public init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        guard let requestType = StatusType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "StatusType")
        }
        self.requestType = requestType
    }
        
    public var data:  Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length
            ])
        data.append(requestType.rawValue)
        return data
    }
}
