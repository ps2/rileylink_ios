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
    case detailedStatus              = 0x02 // Returned on any pod fault
    case dataLog                     = 0x03
    case fault                       = 0x05
    case pulseLogRecent              = 0x50 // dumps up to 50 entries data from the pulse log
    case dumpOlderPulseLog           = 0x51 // like 0x50, but dumps entries before the last 50
    
    public var podInfoType: PodInfo.Type {
        switch self {
        case .normal:
            return StatusResponse.self as! PodInfo.Type
        case .configuredAlerts:
            return PodInfoConfiguredAlerts.self
        case .detailedStatus:
            return DetailedStatus.self
        case .dataLog:
            return PodInfoDataLog.self
        case .fault:
            return PodInfoFault.self
        case .pulseLogRecent:
            return PodInfoPulseLogRecent.self
        case .dumpOlderPulseLog:
            return PodInfoPulseLogPrevious.self
        }
    }
}
