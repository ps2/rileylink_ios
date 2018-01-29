//
//  RFPacket.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 9/16/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct RFPacket {
    public let data: Data
    let packetCounter: Int
    public let rssi: Int

    public init?(rfspyResponse: Data) {
        guard rfspyResponse.count > 2 else {
            return nil
        }
        
        let rssiDec = Int(rfspyResponse[0])
        let rssiOffset = 73
        if rssiDec >= 128 {
            self.rssi = (rssiDec - 256) / 2 - rssiOffset
        } else {
            self.rssi = rssiDec / 2 - rssiOffset
        }

        self.packetCounter = Int(rfspyResponse[1])
        
        self.data = rfspyResponse.subdata(in: 2..<rfspyResponse.count)
    }
}

