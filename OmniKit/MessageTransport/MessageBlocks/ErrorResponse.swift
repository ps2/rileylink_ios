//
//  ErrorResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public let errorResponseCode_badNonce: UInt8 = 0x14

public struct ErrorResponse : MessageBlock {
    
    public let blockType: MessageBlockType = .errorResponse
    
    public let errorResponseCode: UInt8                 // either errorResponseCode_badNonce or something else
    public let nonceSearchKey: UInt16?                  // valid only for the badNonce case
    public let faultEventCode: FaultEventCode?          // valid for all but badNonce cases
    public let podProgressStatus: PodProgressStatus?    // valid for all but badNonce cases

    public let data: Data
    
    // 06 03 14 fa92
    
    public init(encodedData: Data) throws {
        self.data = encodedData
        
        errorResponseCode = encodedData[2]
        if (errorResponseCode == errorResponseCode_badNonce) {
            // For this code only the 2 next bytes are the encoded nonce key.
            nonceSearchKey = encodedData[3...].toBigEndian(UInt16.self)
            faultEventCode = nil
            podProgressStatus = nil
        } else {
            // All other codes are some non-retryable error. In this case,
            // the next 2 bytes are any saved fault code and the pod progress value.
            nonceSearchKey = nil
            faultEventCode = FaultEventCode(rawValue: encodedData[3])
            guard let podProgress = PodProgressStatus(rawValue: encodedData[4]) else {
                throw MessageError.unknownValue(value: encodedData[4], typeDescription: "ErrorResponse PodProgressStatus")
            }
            podProgressStatus = podProgress
        }
    }
}
