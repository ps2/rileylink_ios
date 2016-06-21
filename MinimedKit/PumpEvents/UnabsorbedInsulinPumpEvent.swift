//
//  UnabsorbedInsulinPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct UnabsorbedInsulinPumpEvent: PumpEvent {
    
    public struct Record : DictionaryRepresentable {
        var amount: Double
        var age: Int
        
        init(amount: Double, age: Int) {
            self.amount = amount
            self.age = age
        }
        
        public var dictionaryRepresentation: [String: AnyObject] {
            return [
                "amount": amount,
                "age": age,
            ]
        }
    }
    
    public let length: Int
    
    public let records: [Record]
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        length = Int(max(availableData[1] as UInt8, UInt8(2)))
        var records = [Record]()
        
        guard length <= availableData.length else {
            return nil
        }
        
        func d(idx:Int) -> Int {
            return Int(availableData[idx] as UInt8)
        }
        
        let numRecords = (d(1) - 2) / 3
        
        for idx in 0...(numRecords-1) {
            let record = Record(
                amount:  Double(d(2 + idx * 3)) / 40,
                age: d(3 + idx * 3) + ((d(4 + idx * 3) & 0b110000) << 4))
            records.append(record)
        }

        self.records = records
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "UnabsorbedInsulin",
            "data": records.map({ (r: Record) -> [String: AnyObject] in
                return r.dictionaryRepresentation
            }),
        ]
    }
}
