//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusError : MessageBlock {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
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
//
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10
    
    public let length: UInt8
    public let blockType: MessageBlockType = .statusError
    public let statusMessageBlock: StatusMessageBlock
    public let data: Data
    
    self.statusMessageBlock = statusMessageBlock
    
    public init(encodedData: Data) throws {
        if encodedData.count < Int(16) {
            throw MessageBlockError.notEnoughData
        }
        self.length = encodedData[1]
        self.statusMessageBlock = encodedData[2..16]
    }
}

