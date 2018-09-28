
//
//  PodInfoFlashLog.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFlashLog : PodInfo {
    
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    public var podInfoType: PodInfoResponseSubType
    public let numberOfEntries: UInt16
    public let totalBytes: Int
    public let logEntries: Data
    public let data: Data

    public init(encodedData: Data) throws {
        
        self.numberOfEntries = encodedData[1...2].toBigEndian(UInt16.self)
        self.totalBytes = Int(numberOfEntries << 2) + 3
        
        if encodedData.count < Int(totalBytes) {
            throw MessageBlockError.notEnoughData
        }
       
        self.podInfoType = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.logEntries = encodedData.subdata(in: 3..<totalBytes)
        self.data = encodedData
    }
}
