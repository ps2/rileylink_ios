//
//  PodInfoResponseSubType.swift
//  OmniKit
//
//  Created by Eelke Jager on 15/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PodInfo {
    init(encodedData: Data) throws
    var podInfoType: PodInfoResponseSubType { get }
    var data: Data { get }
    
}

public enum PodInfoResponseSubType: UInt8, Equatable {
    case normal                      = 0x00
    case configuredAlerts            = 0x01
    case faultEvents                 = 0x02
    case dataLog                     = 0x03
    case fault                       = 0x05
    case hardcodedTestValues         = 0x06
    case resetStatus                 = 0x46 // including state, initialization time, any faults
    case flashLogRecent              = 0x50 // dumps up to 50 entries data from the flash log
    case dumpOlderFlashlog           = 0x51 // like 0x50, but dumps entries before the last 50
    
    public var podInfoType: PodInfo.Type {
        switch self {
        case .normal:
            return StatusResponse.self as! PodInfo.Type
        case .configuredAlerts:
            return PodInfoConfiguredAlerts.self
        case .faultEvents:
            return PodInfoFaultEvent.self
        case .dataLog:
            return PodInfoDataLog.self
        case .fault:
            return PodInfoFault.self
        case .hardcodedTestValues:
            return PodInfoTester.self
        case .resetStatus:
            return PodInfoResetStatus.self
        case .flashLogRecent:
            return PodInfoFlashLogRecent.self
        case .dumpOlderFlashlog:
            return PodInfoFlashLogPrevious.self
        }
    }
}
