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
    public let timestamp: NSDateComponents
    let validDateStr: String
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        
        if pumpModel.larger {
            length = 10
        } else {
            length = 7
        }
        
        guard length <= availableData.length else {
            return nil
        }
        
        let dateComponents = NSDateComponents(pumpEventBytes: availableData[5..<7])
        validDateStr = String(format: "%04d-%02d-%02d", dateComponents.year, dateComponents.month, dateComponents.day)
        timestamp = dateComponents
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ResultDailyTotal",
            "timestamp": TimeFormat.timestampStr(TimeFormat.nextMidnightForDateComponents(timestamp)),
            "validDate": validDateStr,
        ]
    }
}
