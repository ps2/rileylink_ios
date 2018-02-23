//
//  CancelBasalCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct CancelBasalCommand : MessageBlock {
    
    // ID1:1f08ced2 PTYPE:PDM SEQ:12 ID2:1f08ced2 B9:08 BLEN:12 MTYPE:190a BODY:c8a1e9874c0000c8010201b3 CRC:80
    // ID1:1f08ced2 PTYPE:PDM SEQ:15 ID2:1f08ced2 B9:10 BLEN:12 MTYPE:190a BODY:e3955e6078370005080282e1 CRC:29
    
    public let blockType: MessageBlockType = .cancelBasal
    public let length: UInt8 = 12
    
    let nonce: UInt32
    let unknownSection: Data
    
    // c8a1e987 4c0000c80102 01b3
    // e3955e60 783700050802 82e1
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length - 2,
            ])
        data.append(contentsOf: nonce.bigEndian)
        data.append(contentsOf: unknownSection)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = UInt32(bigEndian: encodedData.subdata(in: 2..<6))
        self.unknownSection = encodedData.subdata(in: 6..<(encodedData.count))
    }
    
    public init(nonce: UInt32, unknownSection: Data) {
        self.nonce = nonce
        self.unknownSection = unknownSection
    }
}
