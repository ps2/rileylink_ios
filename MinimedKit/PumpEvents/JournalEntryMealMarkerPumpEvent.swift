//
//  JournalEntryMealMarkerPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct JournalEntryMealMarkerPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public let carbohydrates: Double
    public let carbUnits: CarbUnits
    
    public enum CarbUnits: String {
        case Exchanges
        case Grams
    }

    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = 9
        
        let useExchangesBit = ((availableData[8] as UInt8) >> 1) & 0b1
        carbUnits = (useExchangesBit != 0) ? .Exchanges : .Grams
        
        let carbHighBit = (availableData[1] as UInt8) & 0b1
        let carbLowBits = availableData[7] as UInt8
        
        if carbUnits == .Exchanges {
            carbohydrates = Double(carbLowBits) / 10.0
        } else {
            carbohydrates = Double(Int(carbHighBit) << 8 + Int(carbLowBits))
        }

        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]

        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }

    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "JournalEntryMealMarker",
            "carbohydrates": carbohydrates,
            "carbUnits": carbUnits.rawValue,
        ]
    }
}
