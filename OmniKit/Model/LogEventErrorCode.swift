//
//  eventErrorCode.swift
//  OmniKit
//
//  Created by Eelke Jager on 22/10/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation


public struct LogEventErrorCode: CustomStringConvertible, Equatable {
    let rawValue: UInt8
    
    public var eventErrorType: EventErrorType? {
        return EventErrorType(rawValue: rawValue)
    }
    
    public enum EventErrorType: UInt8 {
        case none                                                     = 0
        case immediateBolusInProgress                                 = 1
        case internal2BitVariableSetAndManipulatedInMainLoopRoutines2 = 2
        case internal2BitVariableSetAndManipulatedInMainLoopRoutines3 = 3
        case insulinStateTableCorruption                              = 4
    }
    
    public var description: String {
        let eventErrorDescription: String
        
        if let eventErrorType = eventErrorType {
            eventErrorDescription = {
                switch eventErrorType {
                case .none:
                    return "None"
                case .immediateBolusInProgress:
                    return "Immediate Bolus In Progress"
                case .internal2BitVariableSetAndManipulatedInMainLoopRoutines2:
                    return "Internal 2-Bit Variable Set And Manipulated In Main Loop Routines 0x02"
                case .internal2BitVariableSetAndManipulatedInMainLoopRoutines3:
                    return "Internal 2-Bit Variable Set And Manipulated In Main Loop Routines 0x03"
                case .insulinStateTableCorruption:
                    return "Insulin State Table Corruption"
                }
            }()
        } else {
            eventErrorDescription = "Unknown Log Error State"
        }
        return String(format: "Log Event Error Code 0x%02x: %@", rawValue, eventErrorDescription)
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}
