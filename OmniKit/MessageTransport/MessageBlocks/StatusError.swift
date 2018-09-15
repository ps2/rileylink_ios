//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusError : MessageBlock {

    public let blockType   : MessageBlockType = .statusError
    public let statusType  : StatusMessageBlockType
    public let data        : Data
    
    public init(encodedData: Data) throws {
        // TODO test to evaluate if this works:
        self.statusType = StatusMessageBlockType(rawValue: encodedData[2])!
        self.data = Data(encodedData)
    }
}
