//
//  NonceState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class NonceState {
    var table: [UInt32]
    var idx: UInt8
    
    public init(lot: UInt32, tid: UInt32) {
        table = Array(repeating: UInt32(0), count: 21)
        table[0] = (lot & 0xFFFF) + 0x55543DC3 + (lot >> 16)
        table[0] = table[0] & 0xFFFFFFFF
        table[1] = (tid & 0xFFFF) + 0xAAAAE44E + (tid >> 16)
        table[1] = table[1] & 0xFFFFFFFF
        
        idx = 0
        
        for i in 0..<16 {
            table[2 + i] = generateEntry()
        }

        idx = UInt8((table[0] + table[1]) & 0x0F)
    }
    
    private func generateEntry() -> UInt32 {
        table[0] = ((table[0] >> 16) + (table[0] & 0xFFFF) * 0x5D7F) & 0xFFFFFFFF
        table[1] = ((table[1] >> 16) + (table[1] & 0xFFFF) * 0x8CA0) & 0xFFFFFFFF
        return UInt32((UInt64(table[1]) + (UInt64(table[0]) << 16)) & 0xFFFFFFFF)
    }
    
    func nextNonce() -> UInt32 {
        let nonce = table[Int(2 + idx)]
        table[Int(2 + idx)] = generateEntry()
        idx = UInt8(nonce & 0x0F)
        return nonce
    }
}
