//
//  PodInfoDataLog.swift
//  OmniKit
//
//  Created by Eelke Jager on 22/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoDataLog : PodInfo {
    // CMD 1  2  3  4 5  6 7  8  9 10
    // DATA   0  1  2 3  4 5  6  7  8
    // 02 LL 03 PP QQQQ SSSS 04 3c XXXXXXXX ...

    // dataLogLength = 0x04*numberOfWords+0x08
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    
    public var podInfoType: PodInfoResponseSubType = .dataLog
    public let faultEventCode: FaultEventCode
    public let timeFaultEvent: TimeInterval
    public let timeActivation: TimeInterval
    public let dataChunkSize: UInt8
    public let dataChunkWords: UInt8
    public let data: Data
    // TODO adding a datadump variable based on length
    // length = dataChunckSize * N + 8 where N is the number of dword entries
    // public let loggedData               : Data

    public init(encodedData: Data) throws {
        
        if encodedData.count < 8 {
            throw MessageBlockError.notEnoughData
        }
        self.podInfoType = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.faultEventCode = FaultEventCode(rawValue: encodedData[1])
        self.timeFaultEvent = TimeInterval(minutes: Double((Int(encodedData[2] & 0b1) << 8) + Int(encodedData[3])))
        self.timeActivation = TimeInterval(minutes: Double((Int(encodedData[4] & 0b1) << 8) + Int(encodedData[5])))
        self.dataChunkSize = encodedData[6]
        self.dataChunkWords = encodedData[7]
        
        // self.loggedData          = encodedData[8...encodedData.count]
        self.data                = Data() // Dummy value, else error PodInfo type
    }
}
