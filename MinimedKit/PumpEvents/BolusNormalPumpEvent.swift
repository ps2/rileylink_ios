//
//  BolusNormalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class BolusNormalPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let timestamp: NSDateComponents
    public var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
    public let amount: Double
    public let programmed: Double
    public let unabsorbedInsulinTotal: Double
    public let bolusType: String
    public let duration: Int
    
    public required init?(availableData: NSData, pumpModel: PumpModel) {
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        func insulinDecode(a: Int, b: Int) -> Double {
            return Double((a << 8) + b) / 40.0
        }
        
        if pumpModel.larger {
            length = 13
        } else {
            length = 9
        }
        
        if length > availableData.length {
            amount = 0
            programmed = 0
            unabsorbedInsulinTotal = 0
            duration = 0
            bolusType = "Unset"
            timestamp = NSDateComponents()
            return nil
        }
        
        if pumpModel.larger {
            timestamp = TimeFormat.parse5ByteDate(availableData, offset: 8)
            amount = insulinDecode(d(3), b: d(4))
            programmed = insulinDecode(d(1), b: d(2))
            unabsorbedInsulinTotal = insulinDecode(d(5), b: d(6))
            duration = d(7) * 30
        } else {
            timestamp = TimeFormat.parse5ByteDate(availableData, offset: 4)
            amount = Double(d(2))/10.0
            programmed = Double(d(1))/10.0
            duration = d(3) * 30
            unabsorbedInsulinTotal = 0
        }
        bolusType = duration > 0 ? "square" : "normal"
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var dictionary: [String: AnyObject] = [
            "_type": "BolusNormal",
            "amount": amount,
            "programmed": programmed,
            "type": bolusType,
            "timestamp": TimeFormat.timestampStr(timestamp),
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
