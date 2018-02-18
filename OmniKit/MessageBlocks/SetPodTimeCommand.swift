//
//  SetPodTimeCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/17/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct SetPodTimeCommand : MessageBlock {
    
    public let blockType: MessageBlockType = .setPodTime
    public let length: UInt8 = 19
    
    let address: UInt32
    let date: Date
    let lot: UInt32
    let tid: UInt32

    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            length
            ])
        data.append(contentsOf: self.address.bigEndian)
        
        let cal = Calendar(identifier: .gregorian)
        let components = cal.dateComponents([.day, .month, .year, .hour, .minute], from: date)
        
        let data2 = Data(bytes: [
            UInt8(0x14), // Unknown
            UInt8(0x04), // Unknown
            UInt8(components.day ?? 0),
            UInt8(components.month ?? 0),
            UInt8((components.year ?? 2000) - 2000),
            UInt8(components.hour ?? 0),
            UInt8(components.minute ?? 0)
            ])
        data.append(data2)
        data.append(contentsOf: self.lot.bigEndian)
        data.append(contentsOf: self.tid.bigEndian)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < length+2 {
            throw MessageBlockError.notEnoughData
        }
        self.address = UInt32(bigEndian: encodedData.subdata(in: 2..<6))
        var components = DateComponents()
        components.day = Int(encodedData[8])
        components.month = Int(encodedData[9])
        components.year = Int(encodedData[10]) + 2000
        components.hour = Int(encodedData[11])
        components.minute = Int(encodedData[12])
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            throw MessageBlockError.parseError
        }
        self.date = date
        self.lot = UInt32(bigEndian: encodedData.subdata(in: 13..<17))
        self.tid = UInt32(bigEndian: encodedData.subdata(in: 17..<21))
    }
    
    public init(address: UInt32, date: Date, lot: UInt32, tid: UInt32) {
        self.address = address
        self.date = date
        self.lot = lot
        self.tid = tid
    }
}
