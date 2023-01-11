//
//  NSRemoteAction.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 12/31/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation

public enum NSRemoteAction: Codable {
    case override(name: String, durationTime: TimeInterval?, remoteAddress: String)
    case cancelOverride(remoteAddress: String)
    case bolus(amountInUnits: Double)
    case carbs(amountInGrams: Double, absorptionTime: TimeInterval?, startDate: Date?)
    case closedLoop(active: Bool)
    case autobolus(active: Bool)
    
    public var actionName: String {
        switch self {
        case .carbs:
            return "Carbs"
        case .bolus:
            return "Bolus"
        case .cancelOverride:
            return "Override Cancel"
        case .override:
            return "Override"
        case .closedLoop:
            return "Closed Loop"
        case .autobolus:
            return "Autobolus"
        }
    }
    
    public var actionDetails: String {
        switch self {
        case .carbs(let amountInGrams, _, _):
            return "\(amountInGrams)g"
        case .bolus(let amountInUnits):
            return "\(amountInUnits)u"
        case .cancelOverride:
            return ""
        case .override(let name, _, _):
            return "\(name)"
        case .autobolus(let active):
            return active ? "Activate" : "Deactivate"
        case .closedLoop(let active):
            return active ? "Activate" : "Deactivate"
        }
    }
}
