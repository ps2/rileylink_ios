//
//  GetStatusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation


public enum GetStatusCommandError: Error {
    case unknownRequestType(rawVal: UInt8)
}

public enum StatusRequestType: UInt8 {
    case normal = 0x00
    case bolusCancelResult = 0x01
    // Other types seen: 2, 3, 5, 6, 0x46, 0x50, or 0x51
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
}

struct GetStatusCommand : MessageBlock {
    
    let blockType: MessageBlockType = .getStatus
    public let length: UInt8 = 3
    let requestType: StatusRequestType
    
    init(_ requestType: StatusRequestType = .normal) {
        self.requestType = requestType
    }
    
    init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        guard let requestType = StatusRequestType(rawValue: encodedData[2]) else {
            throw GetStatusCommandError.unknownRequestType(rawVal: encodedData[2])
        }
        self.requestType = requestType
    }
        
    var data: Data {
        let bytes: [UInt8] = [
            blockType.rawValue,
            1,
            requestType.rawValue
        ]
        return Data(bytes)
    }
}
