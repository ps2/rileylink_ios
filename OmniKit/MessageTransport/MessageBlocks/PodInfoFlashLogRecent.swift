//
//  PodInfoFlashLogRecent.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFlashLogRecent : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Pod-Information-Response#Type-50
    // https://github.com/openaps/openomni/wiki/Command-02-Pod-Information-Response#Type-51

    public var podInfoType   : PodInfoResponseSubType = .flashLogRecent
    public let indexLastEntry: UInt8
    public let hexWordLog    : Data
    public let data          : Data

    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(166) {
            throw MessageBlockError.notEnoughData
        }
        self.indexLastEntry = encodedData[2]
        self.hexWordLog     = encodedData.subdata(in: 3..<Int(encodedData[2]))
        self.data           = encodedData
    }
}
