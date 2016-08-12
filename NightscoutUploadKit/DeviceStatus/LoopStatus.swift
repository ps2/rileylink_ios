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
    let version: String
    let timestamp: NSDate

    let iob: IOBStatus?
    let cob: COBStatus?
    let predicted: PredictedBG?
    let recommendedTempBasal: RecommendedTempBasal?
    let recommendedBolus: Double?
    let enacted: LoopEnacted?
    let rileylinks: [RileyLinkStatus]?

    let failureReason: ErrorType?
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["name"] = name
        rval["version"] = version
        rval["timestamp"] = TimeFormat.timestampStrFromDate(timestamp)

        if let iob = iob {
            rval["iob"] = iob.dictionaryRepresentation
        }

        if let cob = cob {
            rval["cob"] = cob.dictionaryRepresentation
        }
        
        if let predicted = predicted {
            rval["predicted"] = predicted.dictionaryRepresentation
        }

        if let recommendedTempBasal = recommendedTempBasal {
            rval["recommendedTempBasal"] = recommendedTempBasal.dictionaryRepresentation
        }

        if let recommendedBolus = recommendedBolus {
            rval["recommendedBolus"] = recommendedBolus
        }
        
        if let enacted = enacted {
            rval["enacted"] = enacted.dictionaryRepresentation
        }
        
        if let failureReason = failureReason {
            rval["failureReason"] = String(failureReason)
        }

        if let rileylinks = rileylinks {
            rval["rileylinks"] = rileylinks.map { $0.dictionaryRepresentation }
        }

        return rval
    }
}

