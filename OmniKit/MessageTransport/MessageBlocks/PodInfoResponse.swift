//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoResponse : MessageBlock {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
    // TODO evaluate length:
    //    public enum lengthType: UInt8{
    //        case normal = 0x10
    //        case configuredAlerts = 0x13
    //        case faultEvents = 0x16
    //        case dataLog = 0x04*numberOfWords+0x08
    //        case faultDataInitializationTime = 0x11
    //        case hardcodedValues  = 0x5
    //        case resetStatus = numberOfBytes & 0x03
    //        case dumpRecentFlashLog = 0x13
    //        case dumpOlderFlashlog = 0x14
    //    public let numberOfWords: UInt8 = 60
    //    public let numberOfBytes: UInt8 = 10
        
    public let blockType   : MessageBlockType = .podInfoResponse
    public let podInfoType : PodInfoType
    public let data        : Data
    
    public init(encodedData: Data) throws {
        // TODO test to evaluate if this works:
        self.podInfoType = PodInfoType(rawValue: encodedData[2])!
        self.data = Data(encodedData)
    }
}
