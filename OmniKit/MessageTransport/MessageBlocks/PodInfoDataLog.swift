//
//  PodInfoDataLog.swift
//  OmniKit
//
//  Created by Eelke Jager on 22/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoDataLog : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
    //        case dataLog = 0x04*numberOfWords+0x08
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    
    public var blockType                : MessageBlockType = .podInfoResponse
    public var podInfoType              : PodInfoResponseSubType = .dataLog
    public let length                   : UInt8
    public let loggedFaultEvent         : FaultEventType
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(4) {
            throw MessageBlockError.notEnoughData
        }
        self.blockType           = MessageBlockType(rawValue: encodedData[0])!
        self.length              = encodedData[1]
        self.podInfoType         = PodInfoResponseSubType(rawValue: encodedData[2])!
        self.loggedFaultEvent    = FaultEventType(rawValue: encodedData[3])!
        // self.dataFromFlashMemory = Data(encodedData[22...124])
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
