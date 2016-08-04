//
//  GetBatteryCarelinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/13/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum BatteryStatus {
    case Low
    case Normal
    case Unknown(rawVal: UInt8)
    
    init(statusByte: UInt8) {
        switch statusByte {
        case 1:
            self = .Low
        case 0:
            self = .Normal
        default:
            self = .Unknown(rawVal: statusByte)
        }
    }
}

public class GetBatteryCarelinkMessageBody: CarelinkLongMessageBody {
    public let status: BatteryStatus
    public let volts: Double
    
    public required init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            volts = 0
            status = .Unknown(rawVal: 0)
            super.init(rxData: rxData)
            return nil
        }
        
        volts = Double(Int(rxData[2] as UInt8) << 8 + Int(rxData[3] as UInt8)) / 100.0
        status = BatteryStatus(statusByte: rxData[1] as UInt8)
        
        super.init(rxData: rxData)
    }
}
