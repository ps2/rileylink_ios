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

public enum PodInfoResponseSubType: UInt8 {
    case normal                      = 0x00
    case configuredAlerts            = 0x01
    case faultEvents                 = 0x02
    case dataLog                     = 0x03
    case fault                       = 0x05
    case hardcodedTestValues         = 0x06
    case flashVariables              = 0x46 // including state, initialization time, any faults
    case flashLogFirst50Entries      = 0x50
    case flashLogNext50Entries       = 0x51
    // https://github.com/openaps/openomni/wiki/Command-0E-Status-Request
    
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
        case .flashVariables:
            return PodInfoFlashVariables.self
        case .flashLogFirst50Entries:
            return PodInfoFlashLog.self
        case .flashLogNext50Entries:
            return PodInfoFlashLog.self
        }
    }
}
