//
//  RFPacket.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 9/16/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

@objc public class RFPacket: NSObject {
    @objc public let data: Data
    @objc public let rssi: Int32
    
    @objc public init(outgoingData: Data) {
        self.data = outgoingData
        rssi = 0
    }
    
    @objc public init?(rfspyResponse: Data) {
        guard rfspyResponse.count > 2 else {
            return nil
        }
        
        let rssiDec:Int = Int(rfspyResponse[0])
        let rssiOffset = 73
        if rssiDec >= 128 {
            self.rssi = Int32((rssiDec - 256) / 2 - rssiOffset)
        } else {
            self.rssi = Int32((rssiDec / 2) - rssiOffset)
        }
        
        guard let decoded = RFPacket.decodeRF(rfspyResponse.subdata(in: 2..<rfspyResponse.count)), decoded.count > 0 else {
            return nil
        }
        
        self.data = decoded.subdata(in: 0..<(decoded.count-1))

        super.init()

        if decoded.last! != data.crc8() {
            return nil
        }
    }
    
    @objc static func decodeRF(_ rawData: Data) -> Data? {
        // Converted from ruby: CODE_SYMBOLS.each{|k,v| puts "@#{Integer("0b"+k)}: @#{Integer("0x"+v)},"};nil
        let codes: [UInt:UInt8] = [21:0,
                     49:1,
                     50:2,
                     35:3,
                     52:4,
                     37:5,
                     38:6,
                     22:7,
                     26:8,
                     25:9,
                     42:10,
                     11:11,
                     44:12,
                     13:13,
                     14:14,
                     28:15]
        
        var output = Data()
        var availBits: UInt = 0
        var x: UInt = 0
        for byte in [UInt8](rawData) {
            x = (x << 8) + UInt(byte)
            availBits += 8
            if (availBits >= 12) {
                let hiNibble = codes[(x >> (availBits - 6))]
                let loNibble = codes[((x >> (availBits - 12)) & UInt(0b111111))]
                if let hiNibble = hiNibble, let loNibble = loNibble {
                    output.append((hiNibble << 4) + loNibble)
                } else {
                    return nil
                }
                availBits -= 12
                x = x & (0xffff >> (16-availBits))
            }
        }
        return output
    }
    
    @objc public func encodedData() -> Data {
        var outData = Data()
        var dataPlusCrc = self.data
        dataPlusCrc.append(data.crc8())
        let codes: [UInt] = [21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28]
        var acc: UInt = 0
        var bitcount: UInt = 0
        for byte in [UInt8](dataPlusCrc) {
            acc <<= 6
            acc |= codes[Int(byte >> 4)]
            bitcount += 6
            
            acc <<= 6
            acc |= codes[Int(byte & 0x0f)]
            bitcount += 6
            
            while bitcount >= 8 {
                let outByte = acc >> (bitcount-8) & UInt(0xff)
                outData.append(UInt8(outByte))
                bitcount -= 8
                acc &= (0xffff >> (UInt(16)-bitcount))
            }
        }
        if bitcount > 0 {
            acc <<= (8-bitcount)
            outData.append(UInt8(acc & 0xff))
        }
        return outData
    }
}

    

