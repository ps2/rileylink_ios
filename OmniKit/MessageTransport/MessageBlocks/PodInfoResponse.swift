//
//  PodInfoResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoResponse : MessageBlock {

    public let blockType              : MessageBlockType = .podInfoResponse
    public let podInfoResponseSubType : PodInfoResponseSubType
    public let podInfo                : PodInfo
    public var data                   : Data

    public init(encodedData: Data) throws {
        let len = encodedData.count
        self.podInfoResponseSubType = PodInfoResponseSubType.init(rawValue: encodedData[2])!
        podInfo = try podInfoResponseSubType.podInfoType.init(encodedData: encodedData.subdata(in: 2..<len))
        self.data = encodedData
    }
}
