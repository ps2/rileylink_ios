//
//  MessageType.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/2/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

public enum MessageType: UInt8 {
    case alert                        = 0x01
    case alertCleared                 = 0x02
    case deviceTest                   = 0x03
    case pumpStatus                   = 0x04
    case pumpAck                      = 0x06
    case pumpBackfill                 = 0x08
    case findDevice                   = 0x09
    case deviceLink                   = 0x0A
    case emptyHistoryPage             = 0x15
    case writeGlucoseHistoryTimestamp = 0x28
    case changeTime                   = 0x40
    case bolus                        = 0x42
    case changeTempBasal              = 0x4c
    case buttonPress                  = 0x5b
    case powerOn                      = 0x5d
    case readTime                     = 0x70
    case getBattery                   = 0x72
    case readRemainingInsulin         = 0x73
    case getHistoryPage               = 0x80
    case getPumpModel                 = 0x8d
    case readTempBasal                = 0x98
    case getGlucosePage               = 0x9A
    case readCurrentPageNumber        = 0x9d
    case readSettings                 = 0xc0
    case readCurrentGlucosePage       = 0xcd
    case readPumpStatus               = 0xce
    
    var bodyType: MessageBody.Type {
        switch self {
        case .alert:
            return MySentryAlertMessageBody.self
        case .alertCleared:
            return MySentryAlertClearedMessageBody.self
        case .pumpStatus:
            return MySentryPumpStatusMessageBody.self
        case .pumpAck:
            return PumpAckMessageBody.self
        case .readSettings:
            return ReadSettingsCarelinkMessageBody.self
        case .readTempBasal:
            return ReadTempBasalCarelinkMessageBody.self
        case .readTime:
            return ReadTimeCarelinkMessageBody.self
        case .findDevice:
            return FindDeviceMessageBody.self
        case .deviceLink:
            return DeviceLinkMessageBody.self
        case .buttonPress:
            return ButtonPressCarelinkMessageBody.self
        case .getPumpModel:
            return GetPumpModelCarelinkMessageBody.self
        case .getHistoryPage:
            return GetHistoryPageCarelinkMessageBody.self
        case .getBattery:
            return GetBatteryCarelinkMessageBody.self
        case .readRemainingInsulin:
            return ReadRemainingInsulinMessageBody.self
        case .readPumpStatus:
            return ReadPumpStatusMessageBody.self
        case .readCurrentGlucosePage:
            return ReadCurrentGlucosePageMessageBody.self
        case .readCurrentPageNumber:
            return ReadCurrentPageNumberMessageBody.self
        case .getGlucosePage:
            return GetGlucosePageMessageBody.self
        default:
            return UnknownMessageBody.self
        }
    }
}
