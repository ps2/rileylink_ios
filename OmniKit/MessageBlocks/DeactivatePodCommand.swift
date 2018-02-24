//
//  DeactivatePodCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct DeactivatePodCommand : MessageBlock {
    
    // ID1:1f00ee84 PTYPE:PDM SEQ:09 ID2:1f00ee84 B9:34 BLEN:6 MTYPE:1c04 BODY:0f7dc4058344 CRC:f1
    
    public let blockType: MessageBlockType = .deactivatePod
    
    let nonce: UInt32
    
    // e1f78752 07 8196
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            4,
            ])
        data.append(contentsOf: nonce.bigEndian)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 6 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = UInt32(bigEndian: encodedData.subdata(in: 2..<6))
    }
    
    public init(nonce: UInt32) {
        self.nonce = nonce
    }
}
