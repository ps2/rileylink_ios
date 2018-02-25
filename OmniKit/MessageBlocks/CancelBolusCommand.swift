//
//  CancelBolusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct CancelBolusCommand : MessageBlock {
    
    // ID1:1f00ee84 PTYPE:PDM SEQ:26 ID2:1f00ee84 B9:ac BLEN:7 MTYPE:1f05 BODY:e1f78752078196 CRC:03
    
    public let blockType: MessageBlockType = .cancelBolus
    
    let nonce: UInt32
    
    // e1f78752 07 8196
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            5,
            ])
        data.appendBigEndian(nonce)
        data.append(0x07) // Bolus type?
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 7 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
    }
    
    public init(nonce: UInt32) {
        self.nonce = nonce
    }
}
