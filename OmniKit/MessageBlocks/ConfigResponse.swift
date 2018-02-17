//
//  ConfigResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigResponse : MessageBlock {

    public let blockType: MessageBlockType = .configResponse
    public let length: UInt8

    public let lotId: UInt32
    public let tid: UInt32
    public let address: UInt32
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        guard encodedData.count >= 15 else {
            throw MessageBlockError.notEnoughData
        }
        
        length = encodedData[1]
        
        guard encodedData.count >= self.length else {
            throw MessageBlockError.notEnoughData
        }

        data = encodedData.subdata(in: 0..<Int(length))

        //01 15 020700020700020200 00a37700 03ab379f 1f00ee87
        //0  1  2                  11       15       19       21

        lotId = UInt32(bigEndian: encodedData.subdata(in: 11..<15))
        tid = UInt32(bigEndian: encodedData.subdata(in: 15..<19))
        address = UInt32(bigEndian: encodedData.subdata(in: 19..<21))
    }
}
