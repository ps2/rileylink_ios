//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusError : MessageBlock {
    
    public let blockType: MessageBlockType = .statusError
 
    public let requestedType: GetStatusCommand.StatusType
    
    public init(requestedType: GetStatusCommand.StatusType = .normal) {
        self.requestedType = requestedType
    }
    
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
    
    public init(encodedData: Data) throws {
        if encodedData.count < 13 {
            throw MessageBlockError.notEnoughData
        }
        
        guard let requestedType = GetStatusCommand.StatusType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "StatusType")
        }
        self.requestedType = requestedType
    }

    public var data:  Data {
        var data = Data(bytes: [
            blockType.rawValue,
            0x13
            ])
        data.append(requestedType.rawValue)
        return data
    }
}
