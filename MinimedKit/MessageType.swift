//
//  MessageType.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/2/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

public enum MessageType: UInt8 {
    case Alert              = 0x01
    case AlertCleared       = 0x02
    case DeviceTest         = 0x03
    case PumpStatus         = 0x04
    case PumpAck            = 0x06
    case PumpBackfill       = 0x08
    case FindDevice         = 0x09
    case DeviceLink         = 0x0A
    case ChangeTime         = 0x40
    case Bolus              = 0x42
    case ChangeTempBasal    = 0x4c
    case ButtonPress        = 0x5b
    case PowerOn            = 0x5d
    case ReadTime           = 0x70
    case GetBattery         = 0x72
    case GetHistoryPage     = 0x80
    case GetPumpModel       = 0x8d
    case ReadTempBasal      = 0x98
    case ReadSettings       = 0xc0

    var bodyType: MessageBody.Type {
        switch self {
        case .Alert:
            return MySentryAlertMessageBody.self
        case .AlertCleared:
            return MySentryAlertClearedMessageBody.self
        case .PumpStatus:
            return MySentryPumpStatusMessageBody.self
        case .PumpAck:
            return PumpAckMessageBody.self
        case .ReadSettings:
            return ReadSettingsCarelinkMessageBody.self
        case .ReadTempBasal:
            return ReadTempBasalCarelinkMessageBody.self
        case .ReadTime:
            return ReadTimeCarelinkMessageBody.self
        case .FindDevice:
          return FindDeviceMessageBody.self
        case .DeviceLink:
          return DeviceLinkMessageBody.self
        case .ButtonPress:
          return ButtonPressCarelinkMessageBody.self
        case .GetPumpModel:
          return GetPumpModelCarelinkMessageBody.self
        case .GetHistoryPage:
          return GetHistoryPageCarelinkMessageBody.self
        case .GetBattery:
          return GetBatteryCarelinkMessageBody.self
        default:
            return UnknownMessageBody.self
        }
    }
}
