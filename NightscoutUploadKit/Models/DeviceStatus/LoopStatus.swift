//
//  LoopStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import HealthKit

public struct LoopStatus {
    typealias RawValue = [String: Any]
    
    public let name: String
    public let version: String
    public let timestamp: Date

    public let iob: IOBStatus?
    public let cob: COBStatus?
    public let predicted: PredictedBG?
    public let recommendedTempBasal: RecommendedTempBasal?
    public let recommendedBolus: Double?
    public let enacted: LoopEnacted?
    public let rileylinks: [RileyLinkStatus]?
    public let failureReason: String?
    public let currentCorrectionRange: CorrectionRange?
    public let forecastError: ForecastError?
    public let testingDetails: [String: Any]?

    public init(name: String, version: String, timestamp: Date, iob: IOBStatus? = nil, cob: COBStatus? = nil, predicted: PredictedBG? = nil, recommendedTempBasal:RecommendedTempBasal? = nil, recommendedBolus: Double? = nil, enacted: LoopEnacted? = nil, rileylinks: [RileyLinkStatus]? = nil, failureReason: Error? = nil, currentCorrectionRange: CorrectionRange? = nil, forecastError: ForecastError? = nil, testingDetails: [String: Any]? = nil) {
        self.name = name
        self.version = version
        self.timestamp = timestamp
        self.iob = iob
        self.cob = cob
        self.predicted = predicted
        self.recommendedTempBasal = recommendedTempBasal
        self.recommendedBolus = recommendedBolus
        self.enacted = enacted
        self.rileylinks = rileylinks
        self.failureReason = String(describing: failureReason)
        self.currentCorrectionRange = currentCorrectionRange
        self.forecastError = forecastError
        self.testingDetails = testingDetails
    }
    
    public var dictionaryRepresentation: [String: Any] {
        var rval = [String: Any]()
        
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
            rval["failureReason"] = failureReason
        }

        if let rileylinks = rileylinks {
            rval["rileylinks"] = rileylinks.map { $0.dictionaryRepresentation }
        }

        if let currentCorrectionRange = currentCorrectionRange {
            rval["currentCorrectionRange"] = currentCorrectionRange.dictionaryRepresentation
        }
        
        if let forecastError = forecastError {
            rval["forecastError"] = forecastError.dictionaryRepresentation
        }
        
        if let testingDetails = testingDetails {
            rval["testingDetails"] = testingDetails
        }

        return rval
    }
    
    init?(rawValue: RawValue) {
        guard
            let name = rawValue["name"] as? String,
            let version = rawValue["version"] as? String,
            let timestampStr = rawValue["timestamp"] as? String,
            let timestamp = TimeFormat.dateFromTimestamp(timestampStr)
        else {
            return nil
        }
        
        self.name = name
        self.version = version
        self.timestamp = timestamp
        
        if let iobRaw = rawValue["iob"] as? IOBStatus.RawValue {
            self.iob = IOBStatus(rawValue: iobRaw)
        } else {
            self.iob = nil
        }

        if let cobRaw = rawValue["cob"] as? COBStatus.RawValue {
            self.cob = COBStatus(rawValue: cobRaw)
        } else {
            self.cob = nil
        }

        if let predictedRaw = rawValue["predicted"] as? PredictedBG.RawValue {
            predicted = PredictedBG(rawValue: predictedRaw)
        } else {
            predicted = nil
        }
        
        if let recommendedTempBasalRaw = rawValue["recommendedTempBasal"] as? RecommendedTempBasal.RawValue {
            recommendedTempBasal = RecommendedTempBasal(rawValue: recommendedTempBasalRaw)
        } else {
            recommendedTempBasal = nil
        }
        
        recommendedBolus = rawValue["recommendedBolus"] as? Double
        
        if let enactedRaw = rawValue["enacted"] as? LoopEnacted.RawValue {
            enacted = LoopEnacted(rawValue: enactedRaw)
        } else {
            enacted = nil
        }
        
        if let rileylinksRaw = rawValue["rileylinks"] as? [RileyLinkStatus.RawValue] {
            rileylinks = rileylinksRaw.compactMap { RileyLinkStatus(rawValue: $0 ) }
        } else {
            rileylinks = nil
        }
        
        failureReason = rawValue["failureReason"] as? String
        
        if let currentCorrectionRangeRaw = rawValue["currentCorrectionRange"] as? CorrectionRange.RawValue {
            currentCorrectionRange = CorrectionRange(rawValue: currentCorrectionRangeRaw)
        } else {
            currentCorrectionRange = nil
        }
        
        if let forecastErrorRaw = rawValue["forecastError"] as? ForecastError.RawValue {
            forecastError = ForecastError(rawValue: forecastErrorRaw)
        } else {
            forecastError = nil
        }
        
        testingDetails = rawValue["testingDetails"] as? [String: Any]

    }
}

