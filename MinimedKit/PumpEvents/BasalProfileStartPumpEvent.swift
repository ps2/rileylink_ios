//
//  BasalProfileStartPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalProfileStartPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: Data
    public let timestamp: DateComponents
    let rate: Double
    let profileIndex: Int
    let offset: Int
    
    
    public init?(availableData: Data, pumpModel: PumpModel) {
        length = 10
        
        guard length <= availableData.count else {
            return nil
        }

        rawData = availableData.subdata(in: 0..<length)
        
        func d(_ idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        timestamp = DateComponents(pumpEventData: availableData, offset: 2)
        rate = Double(d(8)) / 40.0
        profileIndex = d(1)
        offset = d(7) * 30 * 1000 * 60
    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "_type": "BasalProfileStart",
            "offset": offset,
            "rate": rate,
            "profileIndex": profileIndex,
        ]
    }

    public var description: String {
        return String(format: NSLocalizedString("Basal Profile %1$@: %2$@ U/hour", comment: "The format string description of a BasalProfileStartPumpEvent. (1: The index of the profile)(2: The basal rate)"),profileIndex, rate)
    }
}
