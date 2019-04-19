//
//  OmnipodPumpManagerState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import RileyLinkKit
import RileyLinkBLEKit
import LoopKit


public struct OmnipodPumpManagerState: RawRepresentable, Equatable {
    public typealias RawValue = PumpManager.RawStateValue
    
    public static let version = 2
    
    public var podState: PodState?

    public var timeZone: TimeZone
    
    public var basalSchedule: BasalSchedule
    
    public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?

    public var messageLog = MessageLog()

    public var unstoredDoses: [UnfinalizedDose]

    public var expirationReminderDate: Date?

    public init(podState: PodState?, timeZone: TimeZone, basalSchedule: BasalSchedule, rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?) {
        self.podState = podState
        self.timeZone = timeZone
        self.basalSchedule = basalSchedule
        self.rileyLinkConnectionManagerState = rileyLinkConnectionManagerState
        self.unstoredDoses = []
    }
    
    public init?(rawValue: RawValue) {
        
        guard let version = rawValue["version"] as? Int else {
            return nil
        }
        
        let basalSchedule: BasalSchedule
        
        if version == 1 {
            // migrate: basalSchedule moved from podState to oppm state
            if let podStateRaw = rawValue["podState"] as? PodState.RawValue,
                let rawBasalSchedule = podStateRaw["basalSchedule"] as? BasalSchedule.RawValue,
                let migrateSchedule = BasalSchedule(rawValue: rawBasalSchedule)
            {
                basalSchedule = migrateSchedule
            } else {
                return nil
            }
        } else {
            guard let rawBasalSchedule = rawValue["basalSchedule"] as? BasalSchedule.RawValue,
                let schedule = BasalSchedule(rawValue: rawBasalSchedule) else
            {
                return nil
            }
            basalSchedule = schedule
        }
        
        let podState: PodState?
        if let podStateRaw = rawValue["podState"] as? PodState.RawValue {
            podState = PodState(rawValue: podStateRaw)
        } else {
            podState = nil
        }

        let timeZone: TimeZone
        if let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let tz = TimeZone(secondsFromGMT: timeZoneSeconds) {
            timeZone = tz
        } else {
            timeZone = TimeZone.currentFixed
        }
        
        let rileyLinkConnectionManagerState: RileyLinkConnectionManagerState?
        if let rileyLinkConnectionManagerStateRaw = rawValue["rileyLinkConnectionManagerState"] as? RileyLinkConnectionManagerState.RawValue {
            rileyLinkConnectionManagerState = RileyLinkConnectionManagerState(rawValue: rileyLinkConnectionManagerStateRaw)
        } else {
            rileyLinkConnectionManagerState = nil
        }

        self.init(
            podState: podState,
            timeZone: timeZone,
            basalSchedule: basalSchedule,
            rileyLinkConnectionManagerState: rileyLinkConnectionManagerState
        )

        if let rawMessageLog = rawValue["messageLog"] as? MessageLog.RawValue, let messageLog = MessageLog(rawValue: rawMessageLog) {
            self.messageLog = messageLog
        }

        if let expirationReminderDate = rawValue["expirationReminderDate"] as? Date {
            self.expirationReminderDate = expirationReminderDate
        } else if let expiresAt = podState?.expiresAt {
            self.expirationReminderDate = expiresAt.addingTimeInterval(-Pod.expirationReminderAlertDefaultTimeBeforeExpiration)
        }

        if let rawUnstoredDoses = rawValue["unstoredDoses"] as? [UnfinalizedDose.RawValue] {
            self.unstoredDoses = rawUnstoredDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.unstoredDoses = []
        }
    }
    
    public var rawValue: RawValue {
        var value: [String : Any] = [
            "version": OmnipodPumpManagerState.version,
            "timeZone": timeZone.secondsFromGMT(),
            "basalSchedule": basalSchedule.rawValue,
            "messageLog": messageLog.rawValue,
            "unstoredDoses": unstoredDoses.map { $0.rawValue },
        ]
        
        if let podState = podState {
            value["podState"] = podState.rawValue
        }

        if let expirationReminderDate = expirationReminderDate {
            value["expirationReminderDate"] = expirationReminderDate
        }
        
        if let rileyLinkConnectionManagerState = rileyLinkConnectionManagerState {
            value["rileyLinkConnectionManagerState"] = rileyLinkConnectionManagerState.rawValue
        }

        return value
    }
}


extension OmnipodPumpManagerState {
    static let idleListeningEnabledDefaults: RileyLinkDevice.IdleListeningState = .enabled(timeout: .minutes(4), channel: 0)
}


extension OmnipodPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "* timeZone: \(timeZone)",
            "* basalSchedule: \(String(describing: basalSchedule))",
            "* expirationReminderDate: \(String(describing: expirationReminderDate))",
            "* unstoredDoses: \(String(describing: unstoredDoses))",
            String(reflecting: podState),
            String(reflecting: rileyLinkConnectionManagerState),
            String(reflecting: messageLog),
            ].joined(separator: "\n")
    }
}
