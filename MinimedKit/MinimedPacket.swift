//
//  MinimedPacket.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 10/7/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

@objc public class MinimedPacket: NSObject {
    @objc public let data: Data
    
    @objc public init(outgoingData: Data) {
        self.data = outgoingData
    }
    
    @objc public init?(encodedData: Data) {
        
        if let decoded = encodedData.decode4b6b() {
            let msg = decoded.prefix(upTo: (decoded.count - 1))
            if decoded.last != msg.crc8() {
                // CRC invalid
                return nil
            }
            self.data = Data(msg)
        } else {
            // Could not decode message
            return nil
        }
        super.init()
    }
    
    @objc public func encodedData() -> Data {
        var dataWithCRC = self.data
        dataWithCRC.append(data.crc8())
        return Data(dataWithCRC.encode4b6b())
    }
}

