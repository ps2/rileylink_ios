//
//  PodInfoResetStatus.swift
//  OmniKit
//
//  Created by Eelke Jager on 20/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFlashVariables : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
   // 027c4600791f00ee841f00ee84ff00ff00ffffffffffff0000ffffffffffffffffffffffff04060d10070000a62b0004e3db0000ffffffffffffff32cd50af0ff014eb01fe01fe06f9ff00ff0002fd649b14eb14eb07f83cc332cd05fa02fd58a700ffffffffffffffffffffffffffffffffffffffffffffffffffffff2d00658effffffffffffff2d0065
    
    public var podInfoType: PodInfoResponseSubType = .flashVariables
    public let zero: UInt8
    public let numberOfBytes: UInt8
    public let address: UInt32
    public let dataFromFlashMemory: Data
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(122) {
            throw MessageBlockError.notEnoughData
        }
        self.podInfoType = PodInfoResponseSubType(rawValue: encodedData[0])!
        self.zero = encodedData[1]
        self.numberOfBytes = encodedData[2]
        self.address = encodedData[3...6].toBigEndian(UInt32.self)
        self.dataFromFlashMemory = encodedData[20...122]
        self.data = Data() // Dummy value, else error PodInfo type
    }
}
