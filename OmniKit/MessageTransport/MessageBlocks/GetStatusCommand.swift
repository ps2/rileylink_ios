//
//  GetStatusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct GetStatusCommand : MessageBlock {
    // https://github.com/openaps/openomni/wiki/Command-0E-Status-Request

    public let blockType: MessageBlockType = .getStatus
    public let length: UInt8 = 1
    public let podInfoType: PodInfoResponseSubType

//    public enum PodInfoResponseSubType: UInt8, Equatable {
//        case normal                      = 0x00
//        case configuredAlerts            = 0x01
//        case faultEvents                 = 0x02
//        case dataLog                     = 0x03
//        case fault                       = 0x05
//        case hardcodedTestValues         = 0x06
//        case resetStatus                 = 0x46 // including state, initialization time, any faults
//        case flashLogRecent              = 0x50 // dumps up to 50 entries data from the flash log
//        case dumpOlderFlashlog           = 0x51 // like 0x50, but dumps entries before the last 50
//    }
    
    public init(podInfoType: PodInfoResponseSubType = .normal) {
        self.podInfoType = podInfoType
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        guard let podInfoType = PodInfoResponseSubType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "PodInfoResponseSubType")
        }
        self.podInfoType = podInfoType
    }
        
    public var data:  Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length
            ])
        data.append(podInfoType.rawValue)
        return data
    }
}

extension GetStatusCommand: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GetStatusCommand(\(podInfoType))"
    }
}
