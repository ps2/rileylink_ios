//
//  NonceState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class NonceState: RawRepresentable {
    public typealias RawValue = [String: Any]
    
    var table: [UInt32]
    var idx: UInt8
    public let lot: UInt32
    public let tid: UInt32
    
    public init(lot: UInt32 = 0, tid: UInt32 = 0) {
        self.lot = lot
        self.tid = tid
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
    
    public func advanceToNextNonce() {
        let nonce = currentNonce()
        table[Int(2 + idx)] = generateEntry()
        idx = UInt8(nonce & 0x0F)
    }
    
    public func currentNonce() -> UInt32 {
        return table[Int(2 + idx)]
    }
    
    // RawRepresentable
    public required init?(rawValue: RawValue) {
        guard
            let table = rawValue["table"] as? [UInt32],
            let idx = rawValue["idx"] as? UInt8,
            let lot = rawValue["lot"] as? UInt32,
            let tid = rawValue["tid"] as? UInt32
            else {
                return nil
        }
        self.table = table
        self.idx = idx
        self.lot = lot
        self.tid = tid
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "table": table,
            "idx": idx,
            "lot": lot,
            "tid": tid
            ]
        
        return rawValue
    }

}
