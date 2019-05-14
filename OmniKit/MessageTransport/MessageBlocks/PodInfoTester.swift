//
//  PodInfoTester.swift
//  OmniKit
//
//  Created by Eelke Jager on 26/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoTester : PodInfo {
    // OFF 1  2  3  4  5  6
    // 02 05 06 01 00 3F A8
    
    public var podInfoType   : PodInfoResponseSubType = .hardcodedTestValues
    public let byte1         : UInt8
    public let byte2         : UInt8
    public let byte3         : UInt8
    public let byte4         : UInt8
    public let data          : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 7 {
            throw MessageBlockError.notEnoughData
        }
        self.byte1  = encodedData[3]
        self.byte2  = encodedData[4]
        self.byte3  = encodedData[5]
        self.byte4  = encodedData[6]
        self.data   = encodedData
    }
}
