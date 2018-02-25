//
//  RecordBolusCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct RecordBolusCommand : MessageBlock {
    
    public let blockType: MessageBlockType = .recordBolus
    
    public let units: Double
    public let byte2: UInt8
    public let unknownSection: Data
    
    // 17 0d 7c 1770 00030d40 000000000000 00fa
    // 0  1  2  3    5        9
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            0x0d,
            byte2
            ])
        data.appendBigEndian(UInt16(units * 200))
        data.append(unknownSection)
        data.append(Data(hexadecimalString: "000000000000")!)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 15 {
            throw MessageBlockError.notEnoughData
        }
        byte2 = encodedData[2]
        units = Double(encodedData[3...].toBigEndian(UInt16.self)) / 200
        unknownSection = encodedData.subdata(in: 5..<9)
    }
    
    public init(units: Double, byte2: UInt8, unknownSection: Data) {
        self.units = units
        self.byte2 = byte2
        self.unknownSection = unknownSection
    }
}
