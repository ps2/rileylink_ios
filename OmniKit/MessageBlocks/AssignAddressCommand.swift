//
//  AssignAddressCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct AssignAddressCommand : MessageBlock {
    
    public let blockType: MessageBlockType = .assignAddress
    public let length: UInt8 = 6
    
    let address: UInt32

    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            4
        ])
        data.append(contentsOf: self.address.bigEndian)
        return data
    }

    public init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }
        
        self.address = UInt32(bigEndian: encodedData.subdata(in: 2..<6))
    }
    
    public init(address: UInt32) {
        self.address = address
    }
}
