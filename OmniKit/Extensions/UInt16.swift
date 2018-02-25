//
//  UInt16.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

extension UInt16 {
    public var bigEndian: Data {
        get {
            return Data(bytes: [
                UInt8(self >> 8 & 0xff),
                UInt8(self & 0xff)
                ])
        }
    }
    
    public init(bigEndian data: Data) {
        self = UInt16(data[0]) << 8
        self += UInt16(data[1])
    }
    
}
