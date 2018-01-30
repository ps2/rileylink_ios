//
//  RileyLinkCmdSession.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 10/8/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public enum RXFilterMode: UInt8 {
    case wide   = 0x50  // 300KHz
    case narrow = 0x90  // 150KHz
}

public enum CC111XRegister: UInt8 {
    case sync1    = 0x00
    case sync0    = 0x01
    case pktlen   = 0x02
    case pktctrl1 = 0x03
    case pktctrl0 = 0x04
    case fsctrl1  = 0x07
    case freq2    = 0x09
    case freq1    = 0x0a
    case freq0    = 0x0b
    case mdmcfg4  = 0x0c
    case mdmcfg3  = 0x0d
    case mdmcfg2  = 0x0e
    case mdmcfg1  = 0x0f
    case mdmcfg0  = 0x10
    case deviatn  = 0x11
    case mcsm0    = 0x14
    case foccfg   = 0x15
    case agcctrl2 = 0x17
    case agcctrl1 = 0x18
    case agcctrl0 = 0x19
    case frend1   = 0x1a
    case frend0   = 0x1b
    case fscal3   = 0x1c
    case fscal2   = 0x1d
    case fscal1   = 0x1e
    case fscal0   = 0x1f
    case test1    = 0x24
    case test0    = 0x25
    case paTable0 = 0x2e
}

public struct CommandSession {
    let manager: PeripheralManager
    let responseType: PeripheralManager.ResponseType

    /// - Throws: RileyLinkDeviceError
    public func writeCommand(_ command: Command, timeout: TimeInterval) throws -> Data {
        return try manager.writeCommand(command,
            timeout: timeout + PeripheralManager.expectedMaxBLELatency,
            responseType: responseType
        )
    }

    /// - Throws: RileyLinkDeviceError
    public func updateRegister(_ address: CC111XRegister, value: UInt8) throws {
        let command = UpdateRegister(address, value: value)
        let response = try writeCommand(command, timeout: 0)

        guard let rawResponse = response.first else {
            throw RileyLinkDeviceError.invalidResponse(response)
        }

        switch UpdateRegister.Response(rawValue: rawResponse) {
        case .none:
            throw RileyLinkDeviceError.invalidResponse(response)
        case .invalidRegister?:
            throw RileyLinkDeviceError.invalidInput(String(describing: command.register))
        case .success?:
            return
        }
    }

    private static let xtalFrequency = Measurement<UnitFrequency>(value: 24, unit: .megahertz)

    /// - Throws: RileyLinkDeviceError
    public func setBaseFrequency(_ frequency: Measurement<UnitFrequency>) throws {
        let val = Int(
            frequency.converted(to: .hertz).value /
            (CommandSession.xtalFrequency / pow(2, 16)).converted(to: .hertz
        ).value)

        try updateRegister(.freq0, value: UInt8(val & 0xff))
        try updateRegister(.freq1, value: UInt8((val >> 8) & 0xff))
        try updateRegister(.freq2, value: UInt8((val >> 16) & 0xff))
    }
}
