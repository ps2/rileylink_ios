//
//  PumpErrorMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/10/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpErrorCode: UInt8 {
    // commandRefused can happen when temp basal type is set incorrectly, during suspended pump, or unfinished prime.
    case commandRefused  = 0x08
    case maxSettingExceeded  = 0x09
    case bolusInProgress  = 0x0c
    
    public var description: String {
        switch self {
        case .commandRefused:
            return NSLocalizedString("Command Refused", comment: "Pump error code returned when command refused")
        case .maxSettingExceeded:
            return NSLocalizedString("Max Setting Exceeded", comment: "Pump error code describing max setting exceeded")
        case .bolusInProgress:
            return NSLocalizedString("Bolus in progress", comment: "Pump error code when bolus is in progress")
        }
    }
}

public class PumpErrorMessageBody: MessageBody {
    public static let length = 1
    
    let rxData: Data
    public let errorCode: PumpErrorCode?
    public let rawErrorCode: UInt8
    
    public required init?(rxData: Data) {
        self.rxData = rxData
        rawErrorCode = rxData[0]
        errorCode = PumpErrorCode(rawValue: rawErrorCode)
    }
    
    public var txData: Data {
        return rxData
    }
}
