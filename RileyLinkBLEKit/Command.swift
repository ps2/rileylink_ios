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

enum RileyLinkResponseError: UInt8 {
    case rxTimeout          = 0xaa
    case commandInterrupted = 0xbb
    case zeroData           = 0xcc
}

public protocol Command {
    var data: Data { get }
}

public protocol RespondingCommand: Command {
    var expectedResponseLength: Int { get }
}

extension Data {
    mutating func appendBigEndian(_ newElement: UInt32) {
        var element = newElement.byteSwapped
        append(UnsafeBufferPointer(start: &element, count: 1))
    }
}

public struct GetPacket: RespondingCommand {
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

internal struct GetVersion: RespondingCommand {
    let expectedResponseLength = 3

    var data: Data {
        return Data(bytes: [RileyLinkCommand.getVersion.rawValue])
    }
}

public struct SendAndListen: RespondingCommand {
    public let outgoing: Data

    /// In general, 0 = meter, cgm. 2 = pump
    public let sendChannel: UInt8

    /// 0 = no repeat, i.e. only one packet.  1 repeat = 2 packets sent total.
    public let repeatCount: UInt8
    public let delayBetweenPacketsMS: UInt8
    public let listenChannel: UInt8
    public let timeoutMS: UInt32
    public let retryCount: UInt8

    public let expectedResponseLength = 3

    public init(outgoing: Data, sendChannel: UInt8, repeatCount: UInt8, delayBetweenPacketsMS: UInt8, listenChannel: UInt8, timeoutMS: UInt32, retryCount: UInt8) {
        self.outgoing = outgoing
        self.sendChannel = sendChannel
        self.repeatCount = repeatCount
        self.delayBetweenPacketsMS = delayBetweenPacketsMS
        self.listenChannel = listenChannel
        self.timeoutMS = timeoutMS
        self.retryCount = retryCount
    }

    public var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.sendAndListen.rawValue,
            sendChannel,
            repeatCount,
            delayBetweenPacketsMS,
            listenChannel
        ])
        data.appendBigEndian(timeoutMS)
        data.append(retryCount)
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
    public let delayBetweenPacketsMS: UInt8

    public init(outgoing: Data, sendChannel: UInt8, repeatCount: UInt8, delayBetweenPacketsMS: UInt8) {
        self.outgoing = outgoing
        self.sendChannel = sendChannel
        self.repeatCount = repeatCount
        self.delayBetweenPacketsMS = delayBetweenPacketsMS
    }

    public var data: Data {
        var data = Data(bytes: [
            RileyLinkCommand.sendPacket.rawValue,
            sendChannel,
            repeatCount,
            delayBetweenPacketsMS,
        ])
        data.append(outgoing)

        return data
    }
}

struct RegisterSetting {
    let address: CC111XRegister
    let value: UInt8
}

internal struct UpdateRegister: RespondingCommand {
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
