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
        
        self.data = rfspyResponse.subdata(in: 2..<rfspyResponse.count)
        
        super.init()

    }
}

