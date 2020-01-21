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
    public let reservoirVolume: Double?
    
    public init(statusResponse: StatusResponse, validTime: Date, setupUnitsDelivered: Double?) {
        self.validTime = validTime
        self.reservoirVolume = statusResponse.reservoirLevel
        if let setupUnitsDelivered = setupUnitsDelivered {
            self.delivered = statusResponse.insulin - setupUnitsDelivered
        } else {
            // subtract off the fixed setup command values as we don't have an actual value (yet)
            self.delivered = max(statusResponse.insulin - Pod.primeUnits - Pod.cannulaInsertionUnits, 0)
        }
  }
    
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let validTime = rawValue["validTime"] as? Date,
            let delivered = rawValue["delivered"] as? Double
            else {
                return nil
        }
        self.validTime = validTime
        self.delivered = delivered
        self.reservoirVolume = rawValue["reservoirVolume"] as? Double
    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "validTime": validTime,
            "delivered": delivered
            ]
        
        if let reservoirVolume = reservoirVolume {
            rawValue["reservoirVolume"] = reservoirVolume
        }
        
        return rawValue
    }

}

