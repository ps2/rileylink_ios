//
//  BatteryStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/28/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit

public enum BatteryIndicator: String {
    case low = "low"
    case normal = "normal"
}


extension BatteryIndicator {
    public init?(batteryStatus: MinimedKit.BatteryStatus) {
        switch batteryStatus {
        case .low:
            self = .low
        case .normal:
            self = .normal
        default:
            return nil
        }
    }
}


public struct BatteryStatus {
    let percent: Int?
    let voltage: Double?
    let status: BatteryIndicator?
    
    public init(percent: Int? = nil, voltage: Double? = nil, status: BatteryIndicator? = nil) {
        self.percent = percent
        self.voltage = voltage
        self.status = status
    }
    
    public var dictionaryRepresentation: [String: Any] {
        var rval = [String: Any]()
        
        if let percent = percent {
            rval["percent"] = percent
        }
        if let voltage = voltage {
            rval["voltage"] = voltage
        }

        if let status = status {
            rval["status"] = status.rawValue
        }
        
        return rval
    }
}
