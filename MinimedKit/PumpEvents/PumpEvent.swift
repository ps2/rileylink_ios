//
//  PumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PumpEvent : DictionaryRepresentable {
    
    init?(availableData: Data, pumpModel: PumpModel)
    
    var rawData: Data {
        get
    }

    var length: Int {
        get
    }
    
}

public extension PumpEvent {
    public func isDelayedAppend(withPumpModel pumpModel: PumpModel) -> Bool {
                
        switch self {
        case let bolus as BolusNormalPumpEvent:
            //Square boluses for 523's are appended at the beginning of the event
            if pumpModel == .Model523 {
                return bolus.type != .Square
            }
            
            return true
            
        default:
            return false
        }
    }
}
