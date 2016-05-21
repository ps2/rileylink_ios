//
//  GetBatteryCarelinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/13/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class GetBatteryCarelinkMessageBody: CarelinkLongMessageBody {
    public let status: String
    public let volts: Double
    
    public required init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            status = ""
            volts = 0
            super.init(rxData: rxData)
            return nil
        }
        
        volts = Double(Int(rxData[2] as UInt8) << 8 + Int(rxData[3] as UInt8)) / 100.0
        
        if rxData[1] as UInt8 > 0 {
            status = "Low"
        } else {
            status = "Normal"
        }
        
        super.init(rxData: rxData)
    }
}
