//
//  ConfigureAlertsCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigureAlertsCommand : MessageBlock {
    
        // Pairing ConfigureAlerts #1
        // 4c00 0190 0102
        // 4c00 00c8 0102
        // 4c00 00c8 0102
        // 4c00 0096 0102
        // 4c00 0064 0102
    
        // Pairing ConfigureAlerts #2
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802

        // Pairing ConfigureAlerts #3
        // 3800 0ff0 0302
        // 3800 10a4 0302
        // 3800 10a4 0302
        // 3800 10a4 0302
        // 3800 0ff0 0302
    
    
    public let blockType: MessageBlockType = .configureAlerts
    public let length: UInt8 = 12
    
    let nonce: UInt32
    let unknownSection: Data
    
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length - 2,
            ])
        data.appendBigEndian(nonce)
        data.append(contentsOf: unknownSection)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        self.unknownSection = encodedData.subdata(in: 6..<(encodedData.count))
    }
    
    public init(nonce: UInt32, unknownSection: Data) {
        self.nonce = nonce
        self.unknownSection = unknownSection
    }
}
