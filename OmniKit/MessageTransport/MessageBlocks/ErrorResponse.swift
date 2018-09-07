//
//  ErrorResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ErrorResponse : MessageBlock {
    
    public let blockType: MessageBlockType = .errorResponse
    
    public enum ErrorReponseType: UInt8 {
        case badNonce = 0x14
    }

    public let errorReponseType: ErrorReponseType
    public let nonceSearchKey: UInt16

    public let data: Data
    
    // 06 03 14 fa92
    
    public init(encodedData: Data) throws {
        self.data = encodedData
        
        guard let errorReponseType = ErrorReponseType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "ErrorReponseType")
        }
        self.errorReponseType = errorReponseType
        nonceSearchKey = encodedData[3...].toBigEndian(UInt16.self)
    }
}
