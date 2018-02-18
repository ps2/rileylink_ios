//
//  Command.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

public enum MessageBlockError: Error {
    case notEnoughData
    case unknownBlockType(rawVal: UInt8)
    case parseError
}

public enum MessageBlockType: UInt8 {
    case configResponse     = 0x01
    case setPodTime         = 0x03
    case assignAddress      = 0x07
    case getStatus          = 0x0e
    case setInsulinSchedule = 0x1a
    case statusResponse     = 0x1d
    case cancelBolus        = 0x1f
    
    public var blockType: MessageBlock.Type {
        switch self {
        case .getStatus:
            return GetStatusCommand.self
        case .statusResponse:
            return StatusResponse.self
        default:
            return PlaceholderMessageBlock.self
        }
    }
}
    
public protocol MessageBlock {
    init(encodedData: Data) throws

    var blockType: MessageBlockType { get }
    var length: UInt8 { get }
    var data: Data { get  }
}
