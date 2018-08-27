//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusError : MessageBlock {
    
    public let blockType: MessageBlockType = .statusError
    
    public let data: Data
    
    public var length: Int {
        return data.count
    }

    public init(encodedData: Data) throws {
        self.data = encodedData
    }
}
