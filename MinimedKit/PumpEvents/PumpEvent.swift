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
        
        if !pumpModel.mayHaveOutOfOrderEvents {
            return false
        }
        
        switch self {
        case let bolus as BolusNormalPumpEvent:
            //Square boluses for 523's are appended as the beginning of the event
            if pumpModel == .Model523 {
                return bolus.type != .Square
            }
            
            // Square bolus' for some devices are delayed append
            return bolus.type == .Square
            
        default:
            return false
        }
    }
}
