//
//  PumpErrorMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/10/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpErrorCodeType: UInt8 {
    case InvalidTempBasalType  = 0x08
    case MaxSettingExceeded  = 0x09
    case BolusInProgress  = 0x0c
    
    public var description: String {
        switch self {
        case .InvalidTempBasalType:
            return NSLocalizedString("Invalid Temp Basal Type", comment: "Pump error code describing invalid temp basal type")
        case .MaxSettingExceeded:
            return NSLocalizedString("Max Setting Exceeded", comment: "Pump error code describing max setting exceeded")
        case .BolusInProgress:
            return NSLocalizedString("Bolus in progress", comment: "Pump error code when bolus is in progress")
        }
    }
}

public class PumpErrorMessageBody: MessageBody {
    public static let length = 1
    
    let rxData: Data
    public let errorCode: PumpErrorCodeType
    
    public required init?(rxData: Data) {
        guard let errorCode = PumpErrorCodeType(rawValue: rxData[0]) else {
            return nil
        }
        self.rxData = rxData
        self.errorCode = errorCode
    }
    
    public var txData: Data {
        return rxData
    }
}
