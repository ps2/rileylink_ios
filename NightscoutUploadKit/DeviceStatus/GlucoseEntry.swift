//
//  GlucoseEntry.swift
//  NightscoutUploadKit
//
//  Created by Pete Schwamb on 4/19/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//
import Foundation

public struct GlucoseEntry {
    typealias RawValue = [String: Any]

    public var identifier: String
    public var sgv: Double
    public var date: Date
    public var trend: Int?
    public var direction: String?
    public var device: String
    public var type: String

    init?(rawValue: RawValue) {
        
        //Dexcom changed the format of trend in 2021 so we accept both String/Int types
        var trend: Int? = nil
        if let intTrend = rawValue["trend"] as? Int {
            trend = intTrend
        } else if let stringTrend = rawValue["trend"] as? String, let intTrend = Int(stringTrend) {
            trend = intTrend
        }
        
        let direction: String? = rawValue["direction"] as? String
        
        guard
            let identifier = rawValue["_id"] as? String,
            let sgv =  rawValue["sgv"] as? Double,
            let epoch = rawValue["date"] as? Double,
            let device = rawValue["device"] as? String,
            let type = rawValue["type"] as? String
        else {
            return nil
        }

        self.identifier = identifier
        self.sgv = sgv
        self.date = Date(timeIntervalSince1970: epoch / 1000.0)
        self.trend = trend
        self.direction = direction
        self.device = device
        self.type = type

    }
}
