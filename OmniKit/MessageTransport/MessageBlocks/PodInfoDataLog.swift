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
    
    public var podInfoType: PodInfoResponseSubType = .dataLog
    public let faultEventCode: FaultEventCode
    public let data: Data
    public let timeFaultEvent: TimeInterval
    public let timeActivation: TimeInterval
    public let dataChunkSize: UInt8
    public let dataChunkWords: UInt8
    // TODO adding a datadump variable based on length
    //length = dataChunckSize * N + 8 where N is the number of dword entries
    // public let loggedData               : Data
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(6) {
            throw MessageBlockError.notEnoughData
        }
        self.podInfoType = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.faultEventCode = FaultEventCode(rawValue: encodedData[1])
        self.timeFaultEvent = TimeInterval(minutes: Double((Int(encodedData[2] & 0b1) << 8) + Int(encodedData[3])))
        self.timeActivation = TimeInterval(minutes: Double((Int(encodedData[4] & 0b1) << 8) + Int(encodedData[5])))
        self.dataChunkSize = encodedData[6]
        self.dataChunkWords = encodedData[7]
        
        // self.loggedData          = encodedData[10...encodedData.count]
        // self.dataFromFlashMemory = Data(encodedData[22...124])
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
