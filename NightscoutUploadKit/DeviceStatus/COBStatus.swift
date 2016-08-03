//
//  COBStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 8/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct COBStatus {
    let cob: Double
    let timestamp: NSDate

    public init(cob: Double, timestamp: NSDate) {
        self.cob = cob // grams
        self.timestamp = timestamp
    }

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)
        rval["cob"] = cob

        return rval
    }

}