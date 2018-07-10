//
//  MinimedPumpManagerState.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import RileyLinkKit
import RileyLinkBLEKit


public struct MinimedPumpManagerState: RawRepresentable, Equatable {
    public typealias RawValue = PumpManager.RawStateValue

    public static let version = 1

    public var batteryChemistry: BatteryChemistryType

    public var preferredInsulinDataSource: InsulinDataSource

    public var pumpColor: PumpColor

    public var pumpModel: PumpModel

    public var pumpID: String

    public var pumpRegion: PumpRegion

    public var pumpSettings: PumpSettings {
        get {
            return PumpSettings(pumpID: pumpID, pumpRegion: pumpRegion)
        }
        set {
            pumpID = newValue.pumpID
            pumpRegion = newValue.pumpRegion
        }
    }

    public var pumpState: PumpState {
        get {
            var state = PumpState()
            state.pumpModel = pumpModel
            state.timeZone = timeZone
            return state
        }
        set {
            if let model = newValue.pumpModel {
                pumpModel = model
            }
            timeZone = newValue.timeZone
        }
    }

    public var rileyLinkPumpManagerState: RileyLinkPumpManagerState

    public var timeZone: TimeZone

    public init(batteryChemistry: BatteryChemistryType = .alkaline, preferredInsulinDataSource: InsulinDataSource = .pumpHistory, pumpColor: PumpColor, pumpID: String, pumpModel: PumpModel, pumpRegion: PumpRegion, rileyLinkPumpManagerState: RileyLinkPumpManagerState, timeZone: TimeZone) {
        self.batteryChemistry = batteryChemistry
        self.preferredInsulinDataSource = preferredInsulinDataSource
        self.pumpColor = pumpColor
        self.pumpID = pumpID
        self.pumpModel = pumpModel
        self.pumpRegion = pumpRegion
        self.rileyLinkPumpManagerState = rileyLinkPumpManagerState
        self.timeZone = timeZone
    }

    public init?(rawValue: RawValue) {
        guard
            let batteryChemistryRaw = rawValue["batteryChemistry"] as? BatteryChemistryType.RawValue,
            let insulinDataSourceRaw = rawValue["insulinDataSource"] as? InsulinDataSource.RawValue,
            let pumpColorRaw = rawValue["pumpColor"] as? PumpColor.RawValue,
            let pumpID = rawValue["pumpID"] as? String,
            let pumpModelNumber = rawValue["pumpModel"] as? PumpModel.RawValue,
            let pumpRegionRaw = rawValue["pumpRegion"] as? PumpRegion.RawValue,
            let rileyLinkPumpManagerStateRaw = rawValue["rileyLinkPumpManagerState"] as? RileyLinkPumpManagerState.RawValue,
            let timeZoneSeconds = rawValue["timeZone"] as? Int,

            let batteryChemistry = BatteryChemistryType(rawValue: batteryChemistryRaw),
            let insulinDataSource = InsulinDataSource(rawValue: insulinDataSourceRaw),
            let pumpColor = PumpColor(rawValue: pumpColorRaw),
            let pumpModel = PumpModel(rawValue: pumpModelNumber),
            let pumpRegion = PumpRegion(rawValue: pumpRegionRaw),
            let rileyLinkPumpManagerState = RileyLinkPumpManagerState(rawValue: rileyLinkPumpManagerStateRaw),
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
        else {
            return nil
        }

        self.init(
            batteryChemistry: batteryChemistry,
            preferredInsulinDataSource: insulinDataSource,
            pumpColor: pumpColor,
            pumpID: pumpID,
            pumpModel: pumpModel,
            pumpRegion: pumpRegion,
            rileyLinkPumpManagerState: rileyLinkPumpManagerState,
            timeZone: timeZone
        )
    }

    public var rawValue: RawValue {
        return [
            "batteryChemistry": batteryChemistry.rawValue,
            "insulinDataSource": preferredInsulinDataSource.rawValue,
            "pumpColor": pumpColor.rawValue,
            "pumpID": pumpID,
            "pumpModel": pumpModel.rawValue,
            "pumpRegion": pumpRegion.rawValue,
            "rileyLinkPumpManagerState": rileyLinkPumpManagerState.rawValue,
            "timeZone": timeZone.secondsFromGMT(),

            "version": MinimedPumpManagerState.version,
        ]
    }
}


extension MinimedPumpManagerState {
    static let idleListeningEnabledDefaults: RileyLinkDevice.IdleListeningState = .enabled(timeout: .minutes(4), channel: 0)
}


extension MinimedPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## MinimedPumpManagerState",
            "batteryChemistry: \(batteryChemistry)",
            "preferredInsulinDataSource: \(preferredInsulinDataSource)",
            "pumpColor: \(pumpColor)",
            "pumpID: ✔︎",
            "pumpModel: \(pumpModel.rawValue)",
            "pumpRegion: \(pumpRegion)",
            "timeZone: \(timeZone)",
            String(reflecting: rileyLinkPumpManagerState),
        ].joined(separator: "\n")
    }
}
