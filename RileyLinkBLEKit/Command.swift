//
//  Command.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation


// CmdBase
enum RileyLinkCommand: UInt8 {
    case getState         = 1
    case getVersion       = 2
    case getPacket        = 3
    case sendPacket       = 4
    case sendAndListen    = 5
    case updateRegister   = 6
    case reset            = 7
    case led              = 8
    case readRegister     = 9
    case setModeRegisters = 10
}

public enum RileyLinkResponseCode: UInt8 {
    case rxTimeout          = 0xaa
    case commandInterrupted = 0xbb
    case zeroData           = 0xcc
    case success            = 0xdd
    case invalidParam       = 0x11
}

public protocol Command {
    var data: Data { get }
    var expectedResponseLength: Int { get }
}

extension Data {
    mutating func appendBigEndian(_ newElement: UInt32) {
        var element = newElement.byteSwapped
        append(UnsafeBufferPointer(start: &element, count: 1))
    }
    
    mutating func appendBigEndian(_ newElement: UInt16) {
        var element = newElement.byteSwapped
        append(UnsafeBufferPointer(start: &element, count: 1))
    }
}

public struct GetPacket: Command {
    public let listenChannel: UInt8
    public let timeoutMS: UInt32

    public let expectedResponseLength = 3

    public init(listenChannel: UInt8, timeoutMS: UInt32) {
        self.listenChannel = listenChannel
        self.timeoutMS = timeoutMS
    }

    public var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.getPacket.rawValue,
            listenChannel
        ])
        data.appendBigEndian(timeoutMS)

        return data
    }
}

internal struct GetVersion: Command {
    let expectedResponseLength = 3

    var data: Data {
        return Data(bytes: [RileyLinkCommand.getVersion.rawValue])
    }
}

public struct SendAndListen: Command {
    public let outgoing: Data

    /// In general, 0 = meter, cgm. 2 = pump
    public let sendChannel: UInt8

    /// 0 = no repeat, i.e. only one packet.  1 repeat = 2 packets sent total.
    public let repeatCount: UInt8
    public let delayBetweenPacketsMS: UInt16
    public let listenChannel: UInt8
    public let timeoutMS: UInt32
    public let retryCount: UInt8
    public let preambleExtendMS: UInt16
    public let firmwareVersion: RadioFirmwareVersion

    public let expectedResponseLength = 3

    public init(outgoing: Data, sendChannel: UInt8, repeatCount: UInt8, delayBetweenPacketsMS: UInt16, listenChannel: UInt8, timeoutMS: UInt32, retryCount: UInt8, preambleExtendMS: UInt16, firmwareVersion: RadioFirmwareVersion) {
        self.outgoing = outgoing
        self.sendChannel = sendChannel
        self.repeatCount = repeatCount
        self.delayBetweenPacketsMS = delayBetweenPacketsMS
        self.listenChannel = listenChannel
        self.timeoutMS = timeoutMS
        self.retryCount = retryCount
        self.preambleExtendMS = preambleExtendMS
        self.firmwareVersion = firmwareVersion
    }

    public var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.sendAndListen.rawValue,
            sendChannel,
            repeatCount
        ])
        
        if firmwareVersion.supports16SecondPacketDelay {
            data.appendBigEndian(delayBetweenPacketsMS)
        } else {
            data.append(UInt8(delayBetweenPacketsMS & 0xff))
        }
        
        data.append(listenChannel);
        data.appendBigEndian(timeoutMS)
        data.append(retryCount)
        if firmwareVersion.supportsPreambleExtension {
            data.appendBigEndian(preambleExtendMS)
        }
        data.append(outgoing)

        return data
    }
}

public struct SendPacket: Command {
    public let outgoing: Data

    /// In general, 0 = meter, cgm. 2 = pump
    public let sendChannel: UInt8

    /// 0 = no repeat, i.e. only one packet.  1 repeat = 2 packets sent total.
    public let repeatCount: UInt8
    public let delayBetweenPacketsMS: UInt16
    public let preambleExtendMS: UInt16
    public let firmwareVersion: RadioFirmwareVersion
    
    public let expectedResponseLength = 0

    public init(outgoing: Data, sendChannel: UInt8, repeatCount: UInt8, delayBetweenPacketsMS: UInt16, preambleExtendMS: UInt16, firmwareVersion: RadioFirmwareVersion) {
        self.outgoing = outgoing
        self.sendChannel = sendChannel
        self.repeatCount = repeatCount
        self.delayBetweenPacketsMS = delayBetweenPacketsMS
        self.preambleExtendMS = preambleExtendMS
        self.firmwareVersion = firmwareVersion;
    }

    public var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.sendPacket.rawValue,
            sendChannel,
            repeatCount,
        ])
        if firmwareVersion.supports16SecondPacketDelay {
            data.appendBigEndian(delayBetweenPacketsMS)
        } else {
            data.append(UInt8(delayBetweenPacketsMS & 0xff))
        }

        if firmwareVersion.supportsPreambleExtension {
            data.appendBigEndian(preambleExtendMS)
        }
        data.append(outgoing)

        return data
    }
}

public struct RegisterSetting {
    let address: CC111XRegister
    let value: UInt8
}

internal struct UpdateRegister: Command {
    enum Response: UInt8 {
        case success = 1
        case invalidRegister = 2
    }

    let register: RegisterSetting

    let expectedResponseLength = 1

    init(_ address: CC111XRegister, value: UInt8) {
        register = RegisterSetting(address: address, value: value)
    }

    var data: Data {
        return Data(bytes: [
            RileyLinkCommand.updateRegister.rawValue,
            register.address.rawValue,
            register.value,
            0  // Command is 4 bytes long
        ])
    }
}

struct SetModeRegisters: Command {
    enum RegisterModeType: UInt8 {
        case tx = 0x01
        case rx = 0x02
    }

    private var settings: [RegisterSetting] = []

    let registerMode: RegisterModeType
    
    public let expectedResponseLength = 1

    mutating func append(_ registerSetting: RegisterSetting) {
        settings.append(registerSetting)
    }

    var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.setModeRegisters.rawValue,
            registerMode.rawValue
        ])

        for setting in settings {
            data.append(setting.address.rawValue)
            data.append(setting.value)
        }

        return data
    }
}
