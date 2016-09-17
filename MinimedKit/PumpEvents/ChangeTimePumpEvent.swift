//
//  ChangeTimePumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ChangeTimePumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: Data
    public let timestamp: DateComponents
    public let oldTimestamp: DateComponents

    public var adjustmentInterval: TimeInterval {
        return timestamp.date!.timeIntervalSince(oldTimestamp.date!)
    }

    public init?(availableData: Data, pumpModel: PumpModel) {
        length = 14
        
        guard length <= availableData.count else {
            return nil
        }

        rawData = availableData.subdata(in: 0..<length)
        
        oldTimestamp = DateComponents(pumpEventData: availableData, offset: 2)
        timestamp = DateComponents(pumpEventData: availableData, offset: 9)
    }

    public var dictionaryRepresentation: [String: Any] {
        return [
            "_type": "ChangeTime",
        ]
    }
}
