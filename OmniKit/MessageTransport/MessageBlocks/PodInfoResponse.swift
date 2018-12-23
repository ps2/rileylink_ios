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
        if let subType = PodInfoResponseSubType.init(rawValue: encodedData[2]) {
            self.podInfoResponseSubType = subType
        } else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "PodInfoResponseSubType")
        }
        podInfo = try podInfoResponseSubType.podInfoType.init(encodedData: encodedData.subdata(in: 2..<len))
        self.data = encodedData
    }
}

extension PodInfoResponse: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "PodInfoResponse(\(blockType), \(podInfoResponseSubType), \(podInfo)"
    }
}

