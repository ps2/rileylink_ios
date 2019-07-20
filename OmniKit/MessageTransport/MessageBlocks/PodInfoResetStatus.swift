//
//  PodInfoResetStatus.swift
//  OmniKit
//
//  Created by Eelke Jager on 20/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoResetStatus : PodInfo {
    // CMD 1  2  3  4  5 6 7 8 9
    // DATA   0  1  2  3 4 5 6 7
    // 02 LL 46 00 NN POD_ADDR XX ..
    // 02 7c 46 00 79 1f00ee84 1f00ee84ff00ff00ffffffffffff0000ffffffffffffffffffffffff04060d10070000a62b0004e3db0000ffffffffffffff32cd50af0ff014eb01fe01fe06f9ff00ff0002fd649b14eb14eb07f83cc332cd05fa02fd58a700ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    
    public var podInfoType              : PodInfoResponseSubType = .resetStatus
    public let zero                     : UInt8
    public let numberOfBytes            : UInt8
    public let dataFromFlashMemory      : Data
    public let podAddress               : UInt32
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 8 {
            // enough to decode prologue bytes and first 4 bytes of flash which is the Pod Address
            throw MessageBlockError.notEnoughData
        }
        self.podInfoType         = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.zero                = encodedData[1]
        self.numberOfBytes       = encodedData[2]
        self.podAddress          = encodedData[3...6].toBigEndian(UInt32.self)
        if encodedData.count < self.numberOfBytes+3 {
            throw MessageBlockError.notEnoughData
        }
        self.dataFromFlashMemory = Data(encodedData.subdata(in: 3..<Int(encodedData[2]+3)))
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
