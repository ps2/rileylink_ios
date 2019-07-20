//
//  PodInfoFlashLogRecent.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFlashLogRecent : PodInfo {
    // CMD 1  2  3 4  5 6 7 8
    // DATA   0  1 2  3 4 5 6
    // 02 LL 50 IIII XXXXXXXX ...
    // 02 LL 51 NNNN XXXXXXXX ...

    public var podInfoType   : PodInfoResponseSubType = .flashLogRecent
    public let indexLastEntry: UInt8
    public let hexWordLog    : Data
    public let data          : Data

    public init(encodedData: Data) throws {
        
        if encodedData.count < 166 {
            throw MessageBlockError.notEnoughData
        }
        self.indexLastEntry = encodedData[2]
        self.hexWordLog     = encodedData.subdata(in: 3..<Int(encodedData[2]))
        self.data           = encodedData
    }
}
