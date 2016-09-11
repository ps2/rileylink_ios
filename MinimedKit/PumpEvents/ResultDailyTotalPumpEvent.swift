//
//  ResultDailyTotalPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ResultDailyTotalPumpEvent: PumpEvent {
    public let length: Int
    public let rawData: Data
    public let timestamp: DateComponents
    
    public init?(availableData: Data, pumpModel: PumpModel) {
        
        if pumpModel.larger {
            length = 10
        } else {
            length = 7
        }
        
        guard length <= availableData.count else {
            return nil
        }

        rawData = availableData.subdata(in: 0..<length)

        timestamp = DateComponents(pumpEventBytes: availableData.subdata(in: 5..<7))
    }
    
    public var dictionaryRepresentation: [String: Any] {
        return [
            "_type": "ResultDailyTotal",
            "validDate": String(format: "%04d-%02d-%02d", timestamp.year!, timestamp.month!, timestamp.day!),
        ]
    }
}
