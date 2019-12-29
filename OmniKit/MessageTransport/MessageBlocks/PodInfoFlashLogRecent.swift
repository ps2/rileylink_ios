//
//  PodInfoPulseLogRecent.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

fileprivate let maxPumpEntriesReturned = 50

// read (up to) the most recent 50 32-bit pump entries from pulse log
public struct PodInfoPulseLogRecent : PodInfo {
    // CMD 1  2  3 4  5 6 7 8
    // DATA   0  1 2  3 4 5 6
    // 02 LL 50 IIII XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .pulseLogRecent
    public let data          : Data
    public let indexLastEntry: UInt16 // the last pulse entry
    public var pulseLogEntry : [UInt32]

    public init(encodedData: Data) throws {
        if encodedData.count < 3 || ((encodedData.count - 3) & 0x3) != 0 {
            throw MessageBlockError.notEnoughData // first 3 bytes missing or non-integral # of log entries
        }
        let nLogBytesReturned = encodedData.count - 3
        let nLogEntriesReturned = nLogBytesReturned / 4
        let lastPumpEntry = (UInt16(encodedData[1]) << 8) | UInt16(encodedData[2])
        if lastPumpEntry < maxPumpEntriesReturned && nLogEntriesReturned < lastPumpEntry {
            throw MessageBlockError.notEnoughData // small count and we didn't recieve them all
        }
        self.data           = encodedData
        self.indexLastEntry = lastPumpEntry
        self.pulseLogEntry  = Array(repeating: 0, count: nLogEntriesReturned)
        var index = 0
        while index < nLogEntriesReturned {
            self.pulseLogEntry[index] = encodedData[(3+(index*4))...].toBigEndian(UInt32.self)
            index += 1
        }
    }
}

// read (up to) the most previous 50 32-bit pump entries from pulse log
public struct PodInfoPulseLogPrevious : PodInfo {
    // CMD 1  2  3 4  5 6 7 8
    // DATA   0  1 2  3 4 5 6
    // 02 LL 51 NNNN XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .dumpOlderPulseLog
    public let data          : Data
    public let nEntries      : UInt16 // how many 32-bit pump log entries returned
    public var pulseLogEntry : [UInt32]

    public init(encodedData: Data) throws {
        if encodedData.count < 3 || ((encodedData.count - 3) & 0x3) != 0 {
            throw MessageBlockError.notEnoughData // first 3 bytes missing or non-integral # of log entries
        }
        let nLogBytesReturned = encodedData.count - 3
        let nLogEntriesCalculated = nLogBytesReturned / 4
        let nLogEntriesReported = (UInt16(encodedData[1]) << 8) | UInt16(encodedData[2])
        // verify we actually got all the reported entries
        if (nLogEntriesReported > nLogEntriesCalculated) {
            throw MessageBlockError.notEnoughData // some entry count mismatch
        }
        self.data           = encodedData
        self.nEntries       = nLogEntriesReported
        self.pulseLogEntry  = Array(repeating: 0, count: Int(nLogEntriesReported))
        var index = 0
        while index < nLogEntriesReported {
            self.pulseLogEntry[index] = encodedData[(3+(index*4))...].toBigEndian(UInt32.self)
            index += 1
        }
    }
}
