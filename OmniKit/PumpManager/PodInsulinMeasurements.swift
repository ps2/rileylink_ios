//
//  PodInsulinMeasurements.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInsulinMeasurements: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]
    
    public let validTime: Date
    public let delivered: Double
    public let notDelivered: Double
    public let reservoirVolume: Double
    
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let validTime = rawValue["validTime"] as? Date,
            let delivered = rawValue["delivered"] as? Double,
            let notDelivered = rawValue["notDelivered"] as? Double,
            let reservoirVolume = rawValue["reservoirVolume"] as? Double
            else {
                return nil
        }
        self.validTime = validTime
        self.delivered = delivered
        self.notDelivered = notDelivered
        self.reservoirVolume = reservoirVolume
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "validTime": validTime,
            "delivered": delivered,
            "notDelivered": notDelivered,
            "reservoirVolume": reservoirVolume,
            ]
        
        return rawValue
    }

}

