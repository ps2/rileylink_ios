//
//  PodInfoTester.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoTester : PodInfo {
    
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    public var podInfoType   : PodInfoResponseSubType = .hardcodedTestValues
    public let byte1         : UInt8
    public let byte2         : UInt8
    public let byte3         : UInt8
    public let byte4         : UInt8
    public let data          : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(4) {
            throw MessageBlockError.notEnoughData
        }
        self.byte1  = encodedData[1]
        self.byte2  = encodedData[2]
        self.byte3  = encodedData[3]
        self.byte4  = encodedData[4]
        self.data   = encodedData
    }
}
