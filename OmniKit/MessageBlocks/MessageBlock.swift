//
//  Command.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

public enum MessageBlockError: Error {
    case notEnoughData
    case unknownBlockType(rawVal: UInt8)
    case parseError
}

public enum MessageBlockType: UInt8 {
    case configResponse     = 0x01
    case statusError        = 0x02
    case confirmPairing     = 0x03
    case errorResponse      = 0x06
    case assignAddress      = 0x07
    case getStatus          = 0x0e
    case basalScheduleExtra = 0x13
    case tempBasalExtra     = 0x16
    case bolusExtra         = 0x17
    case configureAlerts    = 0x19
    case setInsulinSchedule = 0x1a
    case deactivatePod      = 0x1c
    case statusResponse     = 0x1d
    case cancelDelivery     = 0x1f
    
    public var blockType: MessageBlock.Type {
        switch self {
        case .configResponse:
            return ConfigResponse.self
        case .statusError:
            return StatusError.self
        case .confirmPairing:
            return ConfirmPairingCommand.self
        case .errorResponse:
            return ErrorResponse.self
        case .assignAddress:
            return AssignAddressCommand.self
        case .getStatus:
            return GetStatusCommand.self
        case .basalScheduleExtra:
            return BasalScheduleExtraCommand.self
        case .bolusExtra:
            return BolusExtraCommand.self
        case .configureAlerts:
            return ConfigureAlertsCommand.self
        case .setInsulinSchedule:
            return SetInsulinScheduleCommand.self
        case .deactivatePod:
            return DeactivatePodCommand.self
        case .statusResponse:
            return StatusResponse.self
        case .tempBasalExtra:
            return TempBasalExtraCommand.self
        case .cancelDelivery:
            return CancelDeliveryCommand.self
        }
    }
}
    
public protocol MessageBlock {
    init(encodedData: Data) throws

    var blockType: MessageBlockType { get }
    var data: Data { get  }
}
