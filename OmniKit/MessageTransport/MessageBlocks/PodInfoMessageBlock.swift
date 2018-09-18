//
//  StatusMessageBlock.swift
//  OmniKit
//
//  Created by Eelke Jager on 15/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PodInfoMessageBlockType: UInt8 {
    case normal                      = 0x00
    case configuredAlerts            = 0x01
    case faultEvents                 = 0x02
    //case dataLog                     = 0x03
    //case faultDataInitializationTime = 0x04
    //case hardcodedValues             = 0x06
    //case resetStatus                 = 0x46 // including state, initialization time, any faults
    //case dumpRecentFlashLog          = 0x50
    //case dumpOlderFlashlog           = 0x51 // but dumps entries before the last 50
    // https://github.com/openaps/openomni/wiki/Command-0E-Status-Request
    
    public var podInfoType: PodInfoMessageBlock.Type {
        switch self {
        case .normal:
            return StatusResponse.self as! PodInfoMessageBlock.Type
        case .configuredAlerts:
            return PodInfoConfiguredAlerts.self
        case .faultEvents:
            return PodInfoFaultEvent.self
        //case .dataLog:
        //    print("1")
        //case .faultDataInitializationTime:
        //    print("1")
        //case .hardcodedValues:
        //    print("1")
        //case .resetStatus:
        //    print("1")
        //case .dumpRecentFlashLog:
        //    print("1")
        //case .dumpOlderFlashlog:
        //    print("1")
        }
    }

}

public protocol PodInfoMessageBlock {
    init(encodedData: Data) throws
    var podInfoType: PodInfoMessageBlockType { get }
    var data: Data { get }
}

//extension Data {
//    func statusData(encodedData: Data) -> Data {
//        return encodedData[2...16]
//    }
//}
