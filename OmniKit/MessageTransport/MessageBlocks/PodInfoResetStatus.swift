//
//  PodInfoResetStatus.swift
//  OmniKit
//
//  Created by Eelke Jager on 20/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoResetStatus : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
    //    public enum lengthType: UInt8{
    //        case normal = 0x10
    //        case configuredAlerts = 0x13
    //        case faultEvents = 0x16
    //        case dataLog = 0x04*numberOfWords+0x08
    //        case faultDataInitializationTime = 0x11
    //        case hardcodedValues  = 0x5
    //        case resetStatus = numberOfBytes & 0x03
    //        case dumpRecentFlashLog = 0x13
    //        case dumpOlderFlashlog = 0x14
    //
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    // 027c4600791f00ee841f00ee84ff00ff00ffffffffffff0000ffffffffffffffffffffffff04060d10070000a62b0004e3db0000ffffffffffffff32cd50af0ff014eb01fe01fe06f9ff00ff0002fd649b14eb14eb07f83cc332cd05fa02fd58a700ffffffffffffffffffffffffffffffffffffffffffffffffffffff2d00658effffffffffffff2d0065
    public var blockType                : MessageBlockType = .podInfoResponse
    public var podInfoType              : PodInfoResponseSubType = .resetStatus
    public let length                   : UInt8
    public let zero                     : UInt8
    public let numberOfBytes            : UInt8
    public let address                  : UInt32
    public let dataFromFlashMemory      : Data
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(124) {
            throw MessageBlockError.notEnoughData
        }
        self.blockType           = MessageBlockType(rawValue: encodedData[0])!
        self.length              = encodedData[1]
        self.podInfoType         = PodInfoResponseSubType(rawValue: encodedData[2])!
        self.zero                = encodedData[3]
        self.numberOfBytes       = encodedData[4]
        self.address             = encodedData[5...8].toBigEndian(UInt32.self)
        self.dataFromFlashMemory = Data(encodedData[22...124])
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
