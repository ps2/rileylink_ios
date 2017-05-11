//
//  PumpCommsError.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/9/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit


/// An error that occurs during a command run
///
/// - command: The error took place during the command sequence
/// - arguments: The error took place during the argument sequence
public enum PumpCommandError: Error {
    case command(PumpCommsError)
    case arguments(PumpCommsError)
}

public enum PumpCommsError: Error {
    case rfCommsFailure(String)
    case pumpError(PumpErrorCodeType)
    case unknownPumpModel
    case rileyLinkTimeout
    case unknownResponse(rx: String, during: String)
    case noResponse(during: String)
    case unexpectedResponse(PumpMessage, from: PumpMessage)
    case crosstalk(PumpMessage, during: String)
    case bolusInProgress
    case pumpSuspended
}

public enum SetBolusError: Error {
    case certain(PumpCommsError)
    case uncertain(PumpCommsError)
}


extension SetBolusError: LocalizedError {
    public func errorDescriptionWithUnits(_ units: Double) -> String {
        let format: String
        
        switch self {
        case .certain:
            format = NSLocalizedString("%1$@ U bolus failed", comment: "Describes a certain bolus failure (1: size of the bolus in units)")
        case .uncertain:
            format = NSLocalizedString("%1$@ U bolus may not have succeeded", comment: "Describes an uncertain bolus failure (1: size of the bolus in units)")
        }
        
        return String(format: format, NumberFormatter.localizedString(from: NSNumber(value: units), number: .decimal))
    }
    
    public var failureReason: String? {
        switch self {
        case .certain(let error):
            return error.failureReason
        case .uncertain(let error):
            return error.failureReason
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .certain:
            return NSLocalizedString("It is safe to retry.", comment: "Recovery instruction for a certain bolus failure")
        case .uncertain:
            return NSLocalizedString("Check your pump before retrying.", comment: "Recovery instruction for an uncertain bolus failure")
        }
    }
}


extension PumpCommsError: LocalizedError {
    public var failureReason: String? {
        switch self {
        case .bolusInProgress:
            return NSLocalizedString("A bolus is already in progress.", comment: "Communications error for a bolus currently running")
        case .crosstalk:
            return NSLocalizedString("Comms with another pump detected.", comment: "")
        case .noResponse:
            return NSLocalizedString("Pump did not respond.", comment: "")
        case .pumpSuspended:
            return NSLocalizedString("Pump is suspended.", comment: "")
        case .rfCommsFailure(let msg):
            return msg
        case .rileyLinkTimeout:
            return NSLocalizedString("RileyLink timed out.", comment: "")
        case .unexpectedResponse:
            return NSLocalizedString("Pump responded unexpectedly.", comment: "")
        case .unknownPumpModel:
            return NSLocalizedString("Unknown pump model.", comment: "")
        case .unknownResponse:
            return NSLocalizedString("Unknown response from pump.", comment: "")
        case .pumpError(let errorCode):
            return String(format: NSLocalizedString("Pump error: %1$@", comment: "The format string description of a Pump Error. (1: The specific error code)"),String(describing: errorCode))
        }
    }
}

