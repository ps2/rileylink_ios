//
//  BolusNormalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BolusNormalPumpEvent: TimestampedPumpEvent {

    public enum BolusType: String {
        case Normal
        case Square
    }

    public let length: Int
    public let rawData: NSData
    public let timestamp: NSDateComponents
    public var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
    public let amount: Double
    public let programmed: Double
    public let unabsorbedInsulinTotal: Double
    public let type: BolusType
    public let duration: NSTimeInterval
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        
        func doubleValueFromDataAtIndex(index: Int) -> Double {
            return Double(availableData[index] as UInt8)
        }
        
        func decodeInsulinFromBytes(bytes: [UInt8]) -> Double {
            return Double(Int(bigEndianBytes: bytes)) / Double(pumpModel.strokesPerUnit)
        }
        
        if pumpModel.larger {
            length = 13
        } else {
            length = 9
        }
        
        guard length <= availableData.length else {
            return nil
        }

        rawData = availableData[0..<length]
        
        if pumpModel.larger {
            timestamp = NSDateComponents(pumpEventData: availableData, offset: 8)
            programmed = decodeInsulinFromBytes(availableData[1...2])
            amount = decodeInsulinFromBytes(availableData[3...4])
            unabsorbedInsulinTotal = decodeInsulinFromBytes(availableData[5...6])
            duration = NSTimeInterval(minutes: 30 * doubleValueFromDataAtIndex(7))
        } else {
            timestamp = NSDateComponents(pumpEventData: availableData, offset: 4)
            programmed = decodeInsulinFromBytes([availableData[1]])
            amount = decodeInsulinFromBytes([availableData[2]])
            duration = NSTimeInterval(minutes: 30 * doubleValueFromDataAtIndex(3))
            unabsorbedInsulinTotal = 0
        }
        type = duration > 0 ? .Square : .Normal
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var dictionary: [String: AnyObject] = [
            "_type": "BolusNormal",
            "amount": amount,
            "programmed": programmed,
            "type": type.rawValue,
        ]
        
        if let unabsorbedInsulinRecord = unabsorbedInsulinRecord {
            dictionary["appended"] = unabsorbedInsulinRecord.dictionaryRepresentation
        }
        
        if unabsorbedInsulinTotal > 0 {
            dictionary["unabsorbed"] = unabsorbedInsulinTotal
        }
        
        if duration > 0 {
            dictionary["duration"] = duration
        }
        
        return dictionary
    }
    
}
