//
//  ConfigResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigResponse : MessageBlock {
    
    public enum PairingState: UInt8 {
        case sleeping = 0
        case readyToPair = 1
        case addressAssigned = 2
        case paired = 3
    }

    public let blockType: MessageBlockType = .configResponse
    public let length: UInt8

    public let lot: UInt32
    public let tid: UInt32
    public let address: UInt32?
    public let pairingState: PairingState
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        length = encodedData[1] + 2
        data = encodedData.subdata(in: 0..<Int(length))

        switch length {
        case 0x17:
            // This is the response to the address assignment command
            //01 15 02070002070002 02 0000a640 00097c27 9c 1f08ced2
            //01 15 02070002070002 02 0000a377 0003ab37 9f 1f00ee87
            //0  1  2              9  10       14       18 19
            //AA BB CC             DD EE       FF       GG HH
            
            // AA = mtype (01)
            // BB = length (21)
            // CC = ?
            // DD = pairing state
            // EE = lot id
            // FF = tid
            // GG = RLG/RSSI?
            // HH = address
            
            if let pairingState = PairingState(rawValue: encodedData[9]) {
                self.pairingState = pairingState
            } else {
                throw MessageBlockError.parseError
            }
            
            lot = UInt32(bigEndian: encodedData.subdata(in: 10..<14))
            tid = UInt32(bigEndian: encodedData.subdata(in: 14..<18))
            address = UInt32(bigEndian: encodedData.subdata(in: 19..<23))
            
        case 0x1d:
            // This is the response to the set time command
            //01 1b 13881008340a50 02070002070002 03 0000a640 00097c27
            //01 1b 13881008340a50 02070002070002 03 0000a377 0003ab37
            //0  1  2              9              16 17       21
            //AA BB CC             DD             EE FF       GG
            // AA = mtype (01)
            // BB = length (27)
            // CC = ?
            // DD = ?
            // EE = pairing state
            // FF = lot id
            // GG = tid
            
            if let pairingState = PairingState(rawValue: encodedData[16]) {
                self.pairingState = pairingState
            } else {
                throw MessageBlockError.parseError
            }
            
            lot = UInt32(bigEndian: encodedData.subdata(in: 17..<21))
            tid = UInt32(bigEndian: encodedData.subdata(in: 21..<25))
            address = nil

        default:
            throw MessageBlockError.parseError

        }
    }
}
