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
    
    // dataLogLength = 0x04*numberOfWords+0x08
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    
    public var blockType                : MessageBlockType = .podInfoResponse
    public var podInfoType              : PodInfoResponseSubType = .dataLog
    public let length                   : UInt8 //=dataChunckSize * N + 8 where N is the number of dword entries
    public let loggedFaultEvent         : PodInfoResponseSubType.FaultEventType
    public let data                     : Data
    public let timeFaultEvent           : TimeInterval
    public let timeActivation           : TimeInterval
    public let dataChunkSize            : UInt8
    public let dataChunkWords           : UInt8
    // public let loggedData               : Data
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(6) {
            throw MessageBlockError.notEnoughData
        }
        self.blockType           = MessageBlockType(rawValue: encodedData[0])!
        self.length              = encodedData[1]
        self.podInfoType         = PodInfoResponseSubType(rawValue: encodedData[2])!
        self.loggedFaultEvent    = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[3])!
        self.timeFaultEvent      = TimeInterval(minutes: Double((Int(encodedData[4] & 0b1) << 8) + Int(encodedData[5])))
        self.timeActivation      = TimeInterval(minutes: Double((Int(encodedData[6] & 0b1) << 8) + Int(encodedData[7])))
        self.dataChunkSize       = encodedData[8]
        self.dataChunkWords      = encodedData[9]
        
        // self.loggedData          = encodedData[10...encodedData.count]
        // self.dataFromFlashMemory = Data(encodedData[22...124])
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
