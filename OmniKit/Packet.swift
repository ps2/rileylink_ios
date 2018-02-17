//
//  Packet.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import RileyLinkBLEKit

enum PacketType: UInt8 {
    case pod = 0b111
    case pdm = 0b101
    case con = 0b100
    case ack = 0b010
}

struct Packet {
    let address: UInt32
    let packetType: PacketType
    let sequenceNum: Int
    let data: Data
    
    init(address: UInt32, packetType: PacketType, sequenceNum: Int, data: Data = Data()) {
        self.address = address
        self.packetType = packetType
        self.sequenceNum = sequenceNum
        self.data = data
    }
    
    init?(encodedData: Data) {
        guard encodedData.count >= 7 else {
            // Not enough data for packet
            return nil
        }
        
        self.address = UInt32(bigEndian: encodedData[0..<4])
        guard let packetType = PacketType(rawValue: encodedData[4] >> 5) else {
            // Unknown packet type
            return nil
        }
        self.packetType = packetType
        self.sequenceNum = Int(encodedData[4] & 0b11111)
        
        // Find packet length.
        var candidateData: Data?
        for len in 6..<encodedData.count {
            let tryData = encodedData[0..<len]
            if tryData.crc8() == encodedData[len] {
                candidateData = tryData
                break
            }
        }
        
        guard let data = candidateData else {
            // No interpretation of packet length worked with valid crc
            return nil
        }
        
        self.data = data.subdata(in: 5..<data.count)
    }
    
    func encoded() -> Data {
        var output = address.bigEndian
        output.append(UInt8(packetType.rawValue << 5) + UInt8(sequenceNum & 0b11111))
        output.append(data)
        output.append(output.crc8())
        return output
    }
}

// Extensions for RFPacket support
extension Packet {
    init?(rfPacket: RFPacket) {
        self.init(encodedData: rfPacket.data)
    }
}
