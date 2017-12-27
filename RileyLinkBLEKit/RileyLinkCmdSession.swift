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
    case text0    = 0x25
    case paTable0 = 0x2e
}

public enum RileyLinkDeviceError: Error {
    case rileyLinkTimeout
}

@objc public class RileyLinkCmdSession : NSObject {
    
    let device: RileyLinkBLEDevice?
    
    @objc public init(device: RileyLinkBLEDevice? = nil) {
        self.device = device
    }

    @objc public func doCmd(_ cmd: CmdBase, timeoutMs: Int) -> Bool {
        if let device = device {
            return device.doCmd(cmd, withTimeoutMs: timeoutMs)
        } else {
            return false
        }
    }
    
    public func setRXFilterMode(_ mode: RXFilterMode) throws {
        let drate_e = UInt8(0x9) // exponent of symbol rate (16kbps)
        let chanbw = mode.rawValue
        try updateRegister(.mdmcfg4, value: chanbw | drate_e)
    }
    
    public func updateRegister(_ register: CC111XRegister, value: UInt8) throws {
        let cmd = UpdateRegisterCmd()
        cmd.addr = register.rawValue
        cmd.value = value
        if !doCmd(cmd, timeoutMs: Int(EXPECTED_MAX_BLE_LATENCY_MS)) {
            throw RileyLinkDeviceError.rileyLinkTimeout
        }
    }
    
    public func setBaseFrequency(_ freqMHz: Double) throws {
        let val = Int((freqMHz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
        
        try updateRegister(.freq0, value:UInt8(val & 0xff))
        try updateRegister(.freq1, value:UInt8((val >> 8) & 0xff))
        try updateRegister(.freq2, value:UInt8((val >> 16) & 0xff))
        print("Set frequency to \(freqMHz)")
    }
    
}

