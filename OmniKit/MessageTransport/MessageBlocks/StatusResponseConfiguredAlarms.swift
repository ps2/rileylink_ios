//
//  StatusResponseConfiguredAlarms.swift
//  OmniKit
//
//  Created by Eelke Jager on 16/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusResponseConfiguredAlerts : StatusMessageBlock {

    public var statusType: StatusMessageBlockType = .configuredAlerts
    public var data: Data

    public init(encodedData: Data) throws {
        self.statusType = StatusMessageBlockType(rawValue: encodedData[2])!
        self.data = encodedData[3...13]
    }
    
}

