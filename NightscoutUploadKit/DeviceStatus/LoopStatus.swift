//
//  LoopStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct LoopStatus {
    let name: String
    let timestamp: NSDate
    
    let iob: IOBStatus?
    let cob: COBStatus?
    let suggested: LoopSuggested?
    let enacted: LoopEnacted?
    
    let failureReason: String?
    
    public init(name: String, timestamp: NSDate, glucose: Int? = nil, iob: IOBStatus? = nil, cob: COBStatus? = nil, suggested: LoopSuggested? = nil, enacted: LoopEnacted?, failureReason: String? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.suggested = suggested
        self.enacted = enacted
        self.iob = iob
        self.cob = cob
        self.failureReason = failureReason
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["name"] = name
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        
        if let suggested = suggested {
            rval["suggested"] = suggested.dictionaryRepresentation
        }
        
        if let enacted = enacted {
            rval["enacted"] = enacted.dictionaryRepresentation
        }
        
        if let iob = iob {
            rval["iob"] = iob.dictionaryRepresentation
        }

        if let cob = cob {
            rval["cob"] = cob.dictionaryRepresentation
        }

        return rval
    }
}

