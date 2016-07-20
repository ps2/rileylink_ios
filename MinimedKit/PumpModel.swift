//
//  PumpModel.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//


/// Represents a pump model and its defining characteristics.
/// This class implements the `RawRepresentable` protocol
public enum PumpModel: String {
    case Model508 = "508"
    case Model511 = "511"
    case Model512 = "512"
    case Model515 = "515"
    case Model522 = "522"
    case Model722 = "722"
    case Model523 = "523"
    case Model723 = "723"
    case Model530 = "530"
    case Model730 = "730"
    case Model540 = "540"
    case Model740 = "740"
    case Model551 = "551"
    case Model751 = "751"
    case Model554 = "554"
    case Model754 = "754"

    private var size: Int {
        return Int(rawValue)! / 100
    }

    private var generation: Int {
        return Int(rawValue)! % 100
    }
    
    /// Identifies pumps that support a major-generation shift in record format, starting with the x23.
    /// Mirrors the "larger" flag as defined by decoding-carelink
    public var larger: Bool {
        return generation >= 23
    }
    
    var hasLowSuspend: Bool {
        return generation >= 51
    }
    
    /// The number of turns of the stepper motor required to deliver 1 U of U-100 insulin.
    /// This is a measure of motor precision.
    public var strokesPerUnit: Int {
        return (generation >= 23) ? 40 : 10
    }

    var reservoirCapacity: Double {
        switch size {
        case 5:
            return 176
        case 7:
            return 300
        default:
            fatalError("Unknown reservoir capacity for PumpModel.\(self)")
        }
    }
}


extension PumpModel: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
