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
    case commandRefused      = 0x08
    case maxSettingExceeded  = 0x09
    case bolusInProgress     = 0x0c
    
    public var description: String {
        switch self {
        case .commandRefused:
            return NSLocalizedString("Command refused; check if pump suspended, prime menu unfinished, or temp basal set to %", comment: "Pump error code returned when command refused")
        case .maxSettingExceeded:
            return NSLocalizedString("Pump setting exceeded; Loop's max basal rate is set higher than the pump's max basal rate", comment: "Pump error code describing max setting exceeded")
        case .bolusInProgress:
            return NSLocalizedString("Bolus in progress", comment: "Pump error code when bolus is in progress")
        }
    }
}

public class PumpErrorMessageBody: MessageBody {
    public static let length = 1
    
    let rxData: Data
    public let errorCode: PartialDecode<PumpErrorCode, UInt8>
    
    public required init?(rxData: Data) {
        self.rxData = rxData
        let rawErrorCode = rxData[0]
        if let errorCode = PumpErrorCode(rawValue: rawErrorCode) {
            self.errorCode = .known(errorCode)
        } else {
            self.errorCode = .unknown(rawErrorCode)
        }
    }
    
    public var txData: Data {
        return rxData
    }
}
