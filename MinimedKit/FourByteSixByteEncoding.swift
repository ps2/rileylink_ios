//
//  FourByteSixByteEncoding.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

fileprivate let codesRev:Dictionary<Int, UInt8> = [21: 0, 49: 1, 50: 2, 35: 3, 52: 4, 37: 5, 38: 6, 22: 7, 26: 8, 25: 9, 42: 10, 11: 11, 44: 12, 13: 13, 14: 14, 28: 15]

fileprivate let codes = [21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28]

public extension Sequence where Element == UInt8 {

    public func decode4b6b() -> [UInt8]? {
        var buffer = [UInt8]()
        var availBits = 0
        var x = 0
        for byte in self {
            if byte == 0 {
                break
            }
            
            x = (x << 8) + Int(byte)
            availBits += 8
            if availBits >= 12 {
                guard let
                    hiNibble = codesRev[x >> (availBits - 6)],
                    let loNibble = codesRev[(x >> (availBits - 12)) & 0b111111]
                    else {
                        return nil
                }
                let decoded = UInt8((hiNibble << 4) + loNibble)
                buffer.append(decoded)
                availBits -= 12
                x = x & (0xffff >> (16-availBits))
            }
        }
        return buffer
    }
    
    public func encode4b6b() -> [UInt8] {
        var buffer = [UInt8]()
        var acc = 0x0
        var bitcount = 0
        for byte in self {
            acc <<= 6
            acc |= codes[Int(byte >> 4)]
            bitcount += 6
            
            acc <<= 6
            acc |= codes[Int(byte & 0x0f)]
            bitcount += 6
            
            while bitcount >= 8 {
                buffer.append(UInt8(acc >> (bitcount-8)) & 0xff)
                bitcount -= 8
                acc &= (0xffff >> (16-bitcount))
            }
        }
        if bitcount > 0 {
            acc <<= (8-bitcount)
            buffer.append(UInt8(acc) & 0xff)
        }
        return buffer
    }
}

