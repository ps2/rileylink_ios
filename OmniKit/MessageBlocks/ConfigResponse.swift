//
//  ConfigResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigResponse : MessageBlock {
    
    public struct FirmwareVersion : CustomStringConvertible {
        let major: UInt8
        let minor: UInt8
        let patch: UInt8
        
        public init(encodedData: Data) {
            major = encodedData[0]
            minor = encodedData[1]
            patch = encodedData[2]
        }
        
        public var description: String {
            return "\(major).\(minor).\(patch)"
        }
    }
    
    public enum PairingState: UInt8 {
        case sleeping = 0
        case readyToPair = 1
        case addressAssigned = 2
        case paired = 3
    }

    public let blockType: MessageBlockType = .configResponse

    public let lot: UInt32
    public let tid: UInt32
    public let address: UInt32?
    public let pairingState: PairingState
    public let pmVersion: FirmwareVersion
    public let piVersion: FirmwareVersion
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        let length = encodedData[1] + 2
        data = encodedData.subdata(in: 0..<Int(length))

        switch length {
        case 0x17:
            // This is the response to the address assignment command
            //01 15 020700 020700 02 02 0000a640 00097c27 9c 1f08ced2
            //01 15 020700 020700 02 02 0000a377 0003ab37 9f 1f00ee87
            //0  1  2      5      8  9  10       14       18 19
            //AA BB CC     DD     EE FF GG       HH       II JJ
            
            // AA = mtype (01)
            // BB = length (21)
            // CC = PM
            // DD = PI
            // EE = ?
            // FF = pairing state
            // GG = lot id
            // HH = tid
            // II = RLG/RSSI?
            // JJ = address
            
            if let pairingState = PairingState(rawValue: encodedData[9]) {
                self.pairingState = pairingState
            } else {
                throw MessageBlockError.parseError
            }
            
            pmVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 2..<5))
            piVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 5..<8))
            lot = UInt32(bigEndian: encodedData.subdata(in: 10..<14))
            tid = UInt32(bigEndian: encodedData.subdata(in: 14..<18))
            address = UInt32(bigEndian: encodedData.subdata(in: 19..<23))
            
        case 0x1d:
            // This is the response to the set time command
            //01 1b 13881008340a50 020700 020700 02 03 0000a62b 00044794 1f00ee87
            //0  1  2              9      12     15 16 17       21       25
            //AA BB CC             DD     EE     FF GG HH       II       JJ
            
            // AA = mtype (01)
            // BB = length (27)
            // CC = ?
            // DD = PM
            // EE = PI
            // FF = ?
            // GG = pairing state
            // HH = lot id
            // II = tid
            // JJ = address
            
            if let pairingState = PairingState(rawValue: encodedData[16]) {
                self.pairingState = pairingState
            } else {
                throw MessageBlockError.parseError
            }
            
            pmVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 9..<12))
            piVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 12..<15))
            lot = UInt32(bigEndian: encodedData.subdata(in: 17..<21))
            tid = UInt32(bigEndian: encodedData.subdata(in: 21..<25))
            address = UInt32(bigEndian: encodedData.subdata(in: 25..<29))

        default:
            throw MessageBlockError.parseError

        }
    }
}
