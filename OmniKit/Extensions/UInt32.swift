//
//  UInt32.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

extension UInt32 {
    public var bigEndian: Data {
        get {
            return Data(bytes: [
                UInt8(self >> 24),
                UInt8(self >> 16 & 0xff),
                UInt8(self >> 8 & 0xff),
                UInt8(self & 0xff)
            ])
        }
    }
    
    public init(bigEndian data: Data) {
        self = UInt32(data[0]) << 24
        self += UInt32(data[1]) << 16
        self += UInt32(data[2]) << 8
        self += UInt32(data[3])
    }

}
