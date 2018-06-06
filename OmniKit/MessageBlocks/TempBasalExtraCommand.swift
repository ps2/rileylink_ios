//
//  TempBasalExtraCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 6/6/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct TempBasalExtra : MessageBlock {
    
    public let blockType: MessageBlockType = .tempBasalExtra
    
    public var data: Data {
        return Data()
    }
    
    public init(encodedData: Data) throws {
    }
    
//    public init(units: Double, byte2: UInt8, unknownSection: Data) {
//    }
}
