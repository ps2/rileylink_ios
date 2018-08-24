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

    public static let version = 2

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

    public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?

    public var timeZone: TimeZone

    public init(batteryChemistry: BatteryChemistryType = .alkaline, preferredInsulinDataSource: InsulinDataSource = .pumpHistory, pumpColor: PumpColor, pumpID: String, pumpModel: PumpModel, pumpRegion: PumpRegion, rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?, timeZone: TimeZone) {
        self.batteryChemistry = batteryChemistry
        self.preferredInsulinDataSource = preferredInsulinDataSource
        self.pumpColor = pumpColor
        self.pumpID = pumpID
        self.pumpModel = pumpModel
        self.pumpRegion = pumpRegion
        self.rileyLinkConnectionManagerState = rileyLinkConnectionManagerState
        self.timeZone = timeZone
    }

    public init?(rawValue: RawValue) {
        guard
            let version = rawValue["version"] as? Int,
            let batteryChemistryRaw = rawValue["batteryChemistry"] as? BatteryChemistryType.RawValue,
            let insulinDataSourceRaw = rawValue["insulinDataSource"] as? InsulinDataSource.RawValue,
            let pumpColorRaw = rawValue["pumpColor"] as? PumpColor.RawValue,
            let pumpID = rawValue["pumpID"] as? String,
            let pumpModelNumber = rawValue["pumpModel"] as? PumpModel.RawValue,
            let pumpRegionRaw = rawValue["pumpRegion"] as? PumpRegion.RawValue,
            let timeZoneSeconds = rawValue["timeZone"] as? Int,

            let batteryChemistry = BatteryChemistryType(rawValue: batteryChemistryRaw),
            let insulinDataSource = InsulinDataSource(rawValue: insulinDataSourceRaw),
            let pumpColor = PumpColor(rawValue: pumpColorRaw),
            let pumpModel = PumpModel(rawValue: pumpModelNumber),
            let pumpRegion = PumpRegion(rawValue: pumpRegionRaw),
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
        else {
            return nil
        }
        
        var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? = nil
        
        // Migrate
        if version == 1
        {
            if let oldRileyLinkPumpManagerStateRaw = rawValue["rileyLinkPumpManagerState"] as? [String : Any],
                let connectedPeripheralIDs = oldRileyLinkPumpManagerStateRaw["connectedPeripheralIDs"] as? [String]
            {
                rileyLinkConnectionManagerState = RileyLinkConnectionManagerState(autoConnectIDs: Set(connectedPeripheralIDs))
            }
        } else {
            if let rawState = rawValue["rileyLinkConnectionManagerState"] as? RileyLinkConnectionManagerState.RawValue {
                rileyLinkConnectionManagerState = RileyLinkConnectionManagerState(rawValue: rawState)
            }
        }
        
        self.init(
            batteryChemistry: batteryChemistry,
            preferredInsulinDataSource: insulinDataSource,
            pumpColor: pumpColor,
            pumpID: pumpID,
            pumpModel: pumpModel,
            pumpRegion: pumpRegion,
            rileyLinkConnectionManagerState: rileyLinkConnectionManagerState,
            timeZone: timeZone
        )
    }

    public var rawValue: RawValue {
        var value: [String : Any] = [
            "batteryChemistry": batteryChemistry.rawValue,
            "insulinDataSource": preferredInsulinDataSource.rawValue,
            "pumpColor": pumpColor.rawValue,
            "pumpID": pumpID,
            "pumpModel": pumpModel.rawValue,
            "pumpRegion": pumpRegion.rawValue,
            "timeZone": timeZone.secondsFromGMT(),

            "version": MinimedPumpManagerState.version,
            ]
        
        if let rileyLinkConnectionManagerState = rileyLinkConnectionManagerState {
            value["rileyLinkConnectionManagerState"] = rileyLinkConnectionManagerState.rawValue
        }
        return value
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
            String(reflecting: rileyLinkConnectionManagerState),
        ].joined(separator: "\n")
    }
}
