//
//  StatusResponseConfiguredAlarms.swift
//  OmniKit
//
//  Created by Eelke Jager on 16/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusResponseConfiguredAlerts : StatusMessageBlock {

    
    public let length     : UInt8
    public var statusType : StatusMessageBlockType = .configuredAlerts
    public let data       : Data

    public init(encodedData: Data) throws {
        if encodedData.count < Int(13) {
            throw MessageBlockError.notEnoughData
        }
        
        self.length = encodedData[1]
        self.statusType = StatusMessageBlockType(rawValue: encodedData[2])!
        self.data = Data(encodedData[3...13])
    }
    
}

