//
//  UInt32.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

extension UInt32 {
    public var bigEndianBytes: [UInt8] {
        get {
            return [
                UInt8(self >> 24),
                UInt8(self >> 16 & 0xff),
                UInt8(self >> 8 & 0xff),
                UInt8(self & 0xff)
            ]
        }
    }
    
    public init(bigEndianBytes: [UInt8]) {
        self = UInt32(bigEndianBytes[0]) << 24
        self += UInt32(bigEndianBytes[1]) << 16
        self += UInt32(bigEndianBytes[2]) << 8
        self += UInt32(bigEndianBytes[3])
    }

}
