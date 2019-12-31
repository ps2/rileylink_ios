//
//  PodInfoFlashLogRecent.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

fileprivate let maxPumpEntriesReturned = 50

// read (up to) the most recent 50 32-bit pump entries from flash log
public struct PodInfoFlashLogRecent : PodInfo {
    // CMD 1  2  3 4  5 6 7 8
    // DATA   0  1 2  3 4 5 6
    // 02 LL 50 IIII XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .flashLogRecent
    public let data          : Data
    public let indexLastEntry: UInt16 // how many 32-bit pump log entries total in Pod
    public let hexWordLog    : Data   // TODO make a 32-bit pump log entry type

    public init(encodedData: Data) throws {
        if encodedData.count < 3 || ((encodedData.count - 3) & 0x3) != 0 {
            throw MessageBlockError.notEnoughData // first 3 bytes missing or non-integral # of log entries
        }
        let nLogBytesReturned = encodedData.count - 3
        let nLogEntriesReturned = nLogBytesReturned / 4
        let lastPumpEntry = UInt16((encodedData[1] << 8) | encodedData[2])
        if lastPumpEntry < maxPumpEntriesReturned && nLogEntriesReturned < lastPumpEntry {
            throw MessageBlockError.notEnoughData // small count and we didn't recieve them all
        }
        self.data           = encodedData
        self.indexLastEntry = lastPumpEntry
        self.hexWordLog     = encodedData.subdata(in: 3..<Int(encodedData.count))
    }
    // TODO add code to nicely format the 32-bit pump log entries
}

// read (up to) the most previous 50 32-bit pump entries from flash log
public struct PodInfoFlashLogPrevious : PodInfo {
    // CMD 1  2  3 4  5 6 7 8
    // DATA   0  1 2  3 4 5 6
    // 02 LL 51 NNNN XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .dumpOlderFlashlog
    public let data          : Data
    public let nEntries      : UInt16 // how many 32-bit pump log entries returned
    public let hexWordLog    : Data   // TODO make a 32-bit pump log entry type

    public init(encodedData: Data) throws {
        if encodedData.count < 3 || ((encodedData.count - 3) & 0x3) != 0 {
            throw MessageBlockError.notEnoughData // first 3 bytes missing or non-integral # of log entries
        }
        let nLogBytesReturned = encodedData.count - 3
        let nLogEntriesCalculated = nLogBytesReturned / 4
        let nLogEntriesReported = UInt16((encodedData[1] << 8) | encodedData[2])
        // verify we actually got all the reported entries
        if (nLogEntriesReported > nLogEntriesCalculated) {
            throw MessageBlockError.notEnoughData // some entry count mismatch
        }
        self.data           = encodedData
        self.nEntries       = nLogEntriesReported
        self.hexWordLog     = encodedData.subdata(in: 3..<Int(encodedData.count))
    }
    // TODO add code to nicely format the 32-bit pump log entries
}
