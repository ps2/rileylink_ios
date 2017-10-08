//
//  DeviceSessionContext.swift
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

public enum RileyLinkDeviceError: Error {
    case rileyLinkTimeout
}

open class DeviceSessionContext {
    
    private let expectedMaxBLELatencyMS = 1500
    
    public let session: RileyLinkCmdSession
    
    public init(session: RileyLinkCmdSession) {
        self.session = session
    }
    
    public func setRXFilterMode(_ mode: RXFilterMode) throws {
        let drate_e = UInt8(0x9) // exponent of symbol rate (16kbps)
        let chanbw = mode.rawValue
        try updateRegister(UInt8(CC111X_REG_MDMCFG4), value: chanbw | drate_e)
    }
    
    public func updateRegister(_ addr: UInt8, value: UInt8) throws {
        let cmd = UpdateRegisterCmd()
        cmd.addr = addr
        cmd.value = value
        if !session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
            throw RileyLinkDeviceError.rileyLinkTimeout
        }
    }
    
    public func setBaseFrequency(_ freqMHz: Double) throws {
        let val = Int((freqMHz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
        
        try updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
        print("Set frequency to \(freqMHz)")
    }
    
}

