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
    case errorResponse                = 0x15
    case writeGlucoseHistoryTimestamp = 0x28

    case readRemoteControlID          = 0x2e  // Refused by x23 pumps

    case changeTime                   = 0x40
    case bolus                        = 0x42

    case PumpExperiment_OP67          = 0x43
    case PumpExperiment_OP68          = 0x44
    case PumpExperiment_OP69          = 0x45

    case selectBasalProfile           = 0x4a

    case changeTempBasal              = 0x4c

    case PumpExperiment_OP80          = 0x50
    case PumpExperiment_OP81          = 0x51
    case PumpExperiment_OP82          = 0x52
    case PumpExperiment_OP83          = 0x53
    case PumpExperiment_OP84          = 0x54
    case PumpExperiment_OP85          = 0x55
    case PumpExperiment_OP86          = 0x56
    case PumpExperiment_OP87          = 0x57
    case PumpExperiment_OP88          = 0x58
    case PumpExperiment_OP89          = 0x59
    case PumpExperiment_OP90          = 0x5a

    case buttonPress                  = 0x5b

    case PumpExperiment_OP92          = 0x5c

    case powerOn                      = 0x5d

    case PumpExperiment_OP97          = 0x61
    case PumpExperiment_OP98          = 0x62
    case PumpExperiment_OP99          = 0x63
    case PumpExperiment_O100          = 0x64
    case PumpExperiment_O101          = 0x65
    case PumpExperiment_O103          = 0x67

    case readTime                     = 0x70
    case getBattery                   = 0x72
    case readRemainingInsulin         = 0x73
    case getHistoryPage               = 0x80
    case getPumpModel                 = 0x8d
    case readProfileSTD512            = 0x92
    case readProfileA512              = 0x93
    case readProfileB512              = 0x94
    case readTempBasal                = 0x98
    case getGlucosePage               = 0x9A
    case readCurrentPageNumber        = 0x9d
    case readSettings                 = 0xc0
    case readCurrentGlucosePage       = 0xcd
    case readPumpStatus               = 0xce

    case unknown_e2                   = 0xe2  // a7594040e214190226330000000000021f99011801e00103012c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    case unknown_e6                   = 0xe6  // a7594040e60200190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    case settingsChangeCounter        = 0xec  // Body[3] increments by 1 after changing certain settings 0200af0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

    case readOtherDevicesIDs          = 0xf0
    case readCaptureEventEnabled      = 0xf1  // Body[1] encodes the bool state 0101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    case changeCaptureEventEnable     = 0xf2
    case readOtherDevicesStatus       = 0xf3
    
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
        case .readProfileSTD512:
            return DataFrameMessageBody.self
        case .readProfileA512:
            return DataFrameMessageBody.self
        case .readProfileB512:
            return DataFrameMessageBody.self
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
        case .errorResponse:
            return PumpErrorMessageBody.self
        case .readOtherDevicesIDs:
            return ReadOtherDevicesIDsMessageBody.self
        case .readOtherDevicesStatus:
            return ReadOtherDevicesStatusMessageBody.self
        default:
            return UnknownMessageBody.self
        }
    }
}
