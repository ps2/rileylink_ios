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
    case model508 = "508"
    case model511 = "511"
    case model711 = "711"
    case model512 = "512"
    case model712 = "712"
    case model515 = "515"
    case model715 = "715"
    case model522 = "522"
    case model722 = "722"
    case model523 = "523"
    case model723 = "723"
    case model530 = "530"
    case model730 = "730"
    case model540 = "540"
    case model740 = "740"
    case model551 = "551"
    case model751 = "751"
    case model554 = "554"
    case model754 = "754"

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
    
    // On newer pumps, square wave boluses are added to history on start of delivery, and updated in place
    // when delivery is finished
    public var appendsSquareWaveToHistoryOnStartOfDelivery: Bool {
        return generation >= 23
    }
    
    public var hasMySentry: Bool {
        return generation >= 23
    }
    
    var hasLowSuspend: Bool {
        return generation >= 51
    }

    public var recordsBasalProfileStartEvents: Bool {
        return generation >= 23
    }
    
    // On x15 models, a bolus in progress error is returned when bolusing, even though the bolus succeeds
    public var returnsErrorOnBolus: Bool {
        return generation == 15
    }
    
    /// Newer models allow higher precision delivery, and have bit packing to accomodate this.
    public var insulinBitPackingScale: Int {
        return (generation >= 23) ? 40 : 10
    }

    /// Pulses per unit is the inverse of the minimum volume of delivery.
    public var pulsesPerUnit: Int {
        return (generation >= 23) ? 40 : 20
    }

    public var reservoirCapacity: Int {
        switch size {
        case 5:
            return 176
        case 7:
            return 300
        default:
            fatalError("Unknown reservoir capacity for PumpModel.\(self)")
        }
    }

    /// Even though this is capped by the system at 250 / 10 U, the message takes a UInt16.
    var usesTwoBytesForMaxBolus: Bool {
        return generation >= 23
    }

    public var supportedBasalRates: [Double] {
        if generation >= 23 {
            // 0.025 units (for rates between 0.0-0.975 U/h)
            let rateGroup1 = ((0...39).map { Double($0) / Double(pulsesPerUnit) })
            // 0.05 units (for rates between 1-9.95 U/h)
            let rateGroup2 = ((20...199).map { Double($0) / Double(pulsesPerUnit/2) })
            // 0.1 units (for rates between 10-35 U/h)
            let rateGroup3 = ((100...350).map { Double($0) / Double(pulsesPerUnit/4) })
            return rateGroup1 + rateGroup2 + rateGroup3
        } else {
            // 0.05 units for rates between 0.0-35U/hr
            return (0...700).map { Double($0) / Double(pulsesPerUnit) }
        }
    }

    public var maximumBolusVolume: Double {
        return 25
    }

    public var maximumBasalRate: Double {
        return 35
    }

    public var supportedBolusVolumes: [Double] {
        return supportedBasalRates.filter { $0 <= maximumBolusVolume }
    }

    public var maximumBasalScheduleEntryCount: Int {
        return 48
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return .minutes(30)
    }

    public var isDeliveryRateVariable: Bool {
        return generation >= 23
    }

    public func bolusDeliveryTime(units: Double) -> TimeInterval {
        let unitsPerMinute: Double
        if isDeliveryRateVariable {
            switch units {
            case let u where u < 1.0:
                unitsPerMinute = 0.75
            case let u where u > 7.5:
                unitsPerMinute = units / 5
            default:
                unitsPerMinute = 1.5
            }
        } else {
            unitsPerMinute = 1.5
        }
        return TimeInterval(minutes: units / unitsPerMinute)
    }
}


extension PumpModel: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
