//
//  PodState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public enum SetupProgress: Int {
    case addressAssigned = 0
    case podConfigured
    case startingPrime
    case priming
    case settingInitialBasalSchedule
    case initialBasalScheduleSet
    case startingInsertCannula
    case cannulaInserting
    case completed
    
    public var primingNeeded: Bool {
        return self.rawValue < SetupProgress.priming.rawValue
    }
    
    public var needsInitialBasalSchedule: Bool {
        return self.rawValue < SetupProgress.initialBasalScheduleSet.rawValue
    }

    public var needsCannulaInsertion: Bool {
        return self.rawValue < SetupProgress.completed.rawValue
    }
}

public struct PodState: RawRepresentable, Equatable, CustomDebugStringConvertible {
    
    public typealias RawValue = [String: Any]
    
    public let address: UInt32
    fileprivate var nonceState: NonceState
    public let activatedAt: Date
    public let expiresAt: Date
    public let piVersion: String
    public let pmVersion: String
    public let lot: UInt32
    public let tid: UInt32
    var activeAlertSlots: AlertSet
    public var lastInsulinMeasurements: PodInsulinMeasurements?
    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?
    public var unfinalizedSuspend: UnfinalizedDose?
    public var unfinalizedResume: UnfinalizedDose?
    var finalizedDoses: [UnfinalizedDose]
    public private(set) var suspended: Bool
    public var fault: PodInfoFaultEvent?
    public var messageTransportState: MessageTransportState
    public var primeFinishTime: Date?
    public var setupProgress: SetupProgress
    var configuredAlerts: [AlertSlot: PodAlert]

    public var activeAlerts: [AlertSlot: PodAlert] {
        var active = [AlertSlot: PodAlert]()
        for slot in activeAlertSlots {
            if let alert = configuredAlerts[slot] {
                active[slot] = alert
            }
        }
        return active
    }
    
    public init(address: UInt32, activatedAt: Date, expiresAt: Date, piVersion: String, pmVersion: String, lot: UInt32, tid: UInt32) {
        self.address = address
        self.nonceState = NonceState(lot: lot, tid: tid)
        self.activatedAt = activatedAt
        self.expiresAt = expiresAt
        self.piVersion = piVersion
        self.pmVersion = pmVersion
        self.lot = lot
        self.tid = tid
        self.lastInsulinMeasurements = nil
        self.finalizedDoses = []
        self.suspended = false
        self.fault = nil
        self.activeAlertSlots = .none
        self.messageTransportState = MessageTransportState(packetNumber: 0, messageNumber: 0)
        self.primeFinishTime = nil
        self.setupProgress = .addressAssigned
        self.configuredAlerts = [.slot7: .waitingForPairingReminder]
    }
    
    public var unfinishedPairing: Bool {
        return setupProgress != .completed
    }
    
    public var readyForCannulaInsertion: Bool {
        guard let primeFinishTime = self.primeFinishTime else {
            return false
        }
        return !setupProgress.primingNeeded && primeFinishTime.timeIntervalSinceNow < 0
    }
    
    public var isActive: Bool {
        return setupProgress == .completed && fault == nil
    }
    
    public mutating func advanceToNextNonce() {
        nonceState.advanceToNextNonce()
    }
    
    public var currentNonce: UInt32 {
        return nonceState.currentNonce
    }
    
    public mutating func resyncNonce(syncWord: UInt16, sentNonce: UInt32, messageSequenceNum: Int) {
        let sum = (sentNonce & 0xffff) + UInt32(crc16Table[messageSequenceNum]) + (lot & 0xffff) + (tid & 0xffff)
        let seed = UInt16(sum & 0xffff) ^ syncWord
        nonceState = NonceState(lot: lot, tid: tid, seed: seed)
    }
    
    public mutating func updateFromStatusResponse(_ response: StatusResponse) {
        updateDeliveryStatus(deliveryStatus: response.deliveryStatus)
        lastInsulinMeasurements = PodInsulinMeasurements(statusResponse: response, validTime: Date())
        activeAlertSlots = response.alerts
    }

    public mutating func registerConfiguredAlert(slot: AlertSlot, alert: PodAlert) {
        configuredAlerts[slot] = alert
    }
    
    private mutating func updateDeliveryStatus(deliveryStatus: StatusResponse.DeliveryStatus) {
        let now = Date()
        
        if let bolus = unfinalizedBolus, let finishTime = bolus.finishTime {
            if finishTime <= now {
                finalizedDoses.append(bolus)
                unfinalizedBolus = nil
            } else if bolus.scheduledCertainty == .uncertain {
                if deliveryStatus.bolusing {
                    // Bolus did schedule
                    unfinalizedBolus?.scheduledCertainty = .certain
                } else {
                    // Bolus didn't happen
                    unfinalizedBolus = nil
                }
            }
        }

        if let tempBasal = unfinalizedTempBasal, let finishTime = tempBasal.finishTime {
            if finishTime <= now {
                finalizedDoses.append(tempBasal)
                unfinalizedTempBasal = nil
            } else if tempBasal.scheduledCertainty == .uncertain {
                if deliveryStatus.tempBasalRunning {
                    // Temp basal did schedule
                    unfinalizedTempBasal?.scheduledCertainty = .certain
                } else {
                    // Temp basal didn't happen
                    unfinalizedTempBasal = nil
                }
            }
        }

        if let resume = unfinalizedResume, resume.scheduledCertainty == .uncertain {
            if deliveryStatus != .suspended {
                // Resume was enacted
                unfinalizedResume?.scheduledCertainty = .certain
            } else {
                // Resume wasn't enacted
                unfinalizedResume = nil
            }
        }

        if let suspend = unfinalizedSuspend {
            if suspend.scheduledCertainty == .uncertain {
                if deliveryStatus == .suspended {
                    // Suspend was enacted
                    unfinalizedSuspend?.scheduledCertainty = .certain
                } else {
                    // Suspend wasn't enacted
                    unfinalizedSuspend = nil
                }
            }

            if let resume = unfinalizedResume, suspend.startTime < resume.startTime {
                finalizedDoses.append(suspend)
                finalizedDoses.append(resume)
                unfinalizedSuspend = nil
                unfinalizedResume = nil
            }
        }

        suspended = deliveryStatus == .suspended
    }

    // MARK: - RawRepresentable
    public init?(rawValue: RawValue) {

        guard
            let address = rawValue["address"] as? UInt32,
            let nonceStateRaw = rawValue["nonceState"] as? NonceState.RawValue,
            let nonceState = NonceState(rawValue: nonceStateRaw),
            let activatedAt = rawValue["activatedAt"] as? Date,
            let expiresAt = rawValue["expiresAt"] as? Date,
            let piVersion = rawValue["piVersion"] as? String,
            let pmVersion = rawValue["pmVersion"] as? String,
            let lot = rawValue["lot"] as? UInt32,
            let tid = rawValue["tid"] as? UInt32
            else {
                return nil
            }
        
        self.address = address
        self.nonceState = nonceState
        self.activatedAt = activatedAt
        self.expiresAt = expiresAt
        self.piVersion = piVersion
        self.pmVersion = pmVersion
        self.lot = lot
        self.tid = tid
        
        if let suspended = rawValue["suspended"] as? Bool {
            self.suspended = suspended
        } else {
            self.suspended = false
        }

        if let rawUnfinalizedBolus = rawValue["unfinalizedBolus"] as? UnfinalizedDose.RawValue,
            let unfinalizedBolus = UnfinalizedDose(rawValue: rawUnfinalizedBolus)
        {
            self.unfinalizedBolus = unfinalizedBolus
        } else {
            self.unfinalizedBolus = nil
        }

        if let rawUnfinalizedTempBasal = rawValue["unfinalizedTempBasal"] as? UnfinalizedDose.RawValue,
            let unfinalizedTempBasal = UnfinalizedDose(rawValue: rawUnfinalizedTempBasal)
        {
            self.unfinalizedTempBasal = unfinalizedTempBasal
        } else {
            self.unfinalizedTempBasal = nil
        }

        if let rawUnfinalizedSuspend = rawValue["unfinalizedSuspend"] as? UnfinalizedDose.RawValue,
            let unfinalizedSuspend = UnfinalizedDose(rawValue: rawUnfinalizedSuspend)
        {
            self.unfinalizedSuspend = unfinalizedSuspend
        } else {
            self.unfinalizedSuspend = nil
        }

        if let rawUnfinalizedResume = rawValue["unfinalizedResume"] as? UnfinalizedDose.RawValue,
            let unfinalizedResume = UnfinalizedDose(rawValue: rawUnfinalizedResume)
        {
            self.unfinalizedResume = unfinalizedResume
        } else {
            self.unfinalizedResume = nil
        }

        if let rawLastInsulinMeasurements = rawValue["lastInsulinMeasurements"] as? PodInsulinMeasurements.RawValue {
            self.lastInsulinMeasurements = PodInsulinMeasurements(rawValue: rawLastInsulinMeasurements)
        } else {
            self.lastInsulinMeasurements = nil
        }
        
        if let rawFinalizedDoses = rawValue["finalizedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finalizedDoses = rawFinalizedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finalizedDoses = []
        }
        
        if let rawFault = rawValue["fault"] as? PodInfoFaultEvent.RawValue {
            self.fault = PodInfoFaultEvent(rawValue: rawFault)
        } else {
            self.fault = nil
        }
        
        if let alarmsRawValue = rawValue["alerts"] as? UInt8 {
            self.activeAlertSlots = AlertSet(rawValue: alarmsRawValue)
        } else {
            self.activeAlertSlots = .none
        }
        
        if let setupProgressRaw = rawValue["setupProgress"] as? Int,
            let setupProgress = SetupProgress(rawValue: setupProgressRaw)
        {
            self.setupProgress = setupProgress
        } else {
            // Migrate
            self.setupProgress = .completed
        }
        
        if let messageTransportStateRaw = rawValue["messageTransportState"] as? MessageTransportState.RawValue,
            let messageTransportState = MessageTransportState(rawValue: messageTransportStateRaw)
        {
            self.messageTransportState = messageTransportState
        } else {
            self.messageTransportState = MessageTransportState(packetNumber: 0, messageNumber: 0)
        }

        if let rawConfiguredAlerts = rawValue["configuredAlerts"] as? [String: PodAlert.RawValue] {
            var configuredAlerts = [AlertSlot: PodAlert]()
            for (rawSlot, rawAlert) in rawConfiguredAlerts {
                if let slotNum = UInt8(rawSlot), let slot = AlertSlot(rawValue: slotNum), let alert = PodAlert(rawValue: rawAlert) {
                    configuredAlerts[slot] = alert
                }
            }
            self.configuredAlerts = configuredAlerts
        } else {
            // Assume migration, and set up with alerts that are normally configured
            self.configuredAlerts = [
                .slot2: .shutdownImminentAlarm(0),
                .slot3: .expirationAlert(0),
                .slot4: .lowReservoirAlarm(0),
                .slot7: .expirationAdvisoryAlarm(alarmTime: 0, duration: 0)
            ]
        }
        
        self.primeFinishTime = rawValue["primeFinishTime"] as? Date
    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "address": address,
            "nonceState": nonceState.rawValue,
            "activatedAt": activatedAt,
            "expiresAt": expiresAt,
            "piVersion": piVersion,
            "pmVersion": pmVersion,
            "lot": lot,
            "tid": tid,
            "suspended": suspended,
            "finalizedDoses": finalizedDoses.map( { $0.rawValue }),
            "alerts": activeAlertSlots.rawValue,
            "messageTransportState": messageTransportState.rawValue,
            "setupProgress": setupProgress.rawValue
            ]
        
        if let unfinalizedBolus = self.unfinalizedBolus {
            rawValue["unfinalizedBolus"] = unfinalizedBolus.rawValue
        }
        
        if let unfinalizedTempBasal = self.unfinalizedTempBasal {
            rawValue["unfinalizedTempBasal"] = unfinalizedTempBasal.rawValue
        }

        if let unfinalizedSuspend = self.unfinalizedSuspend {
            rawValue["unfinalizedSuspend"] = unfinalizedSuspend.rawValue
        }

        if let unfinalizedResume = self.unfinalizedResume {
            rawValue["unfinalizedResume"] = unfinalizedResume.rawValue
        }

        if let lastInsulinMeasurements = self.lastInsulinMeasurements {
            rawValue["lastInsulinMeasurements"] = lastInsulinMeasurements.rawValue
        }
        
        if let fault = self.fault {
            rawValue["fault"] = fault.rawValue
        }

        if let primeFinishTime = primeFinishTime {
            rawValue["primeFinishTime"] = primeFinishTime
        }

        if configuredAlerts.count > 0 {
            let rawConfiguredAlerts = Dictionary(uniqueKeysWithValues:
                configuredAlerts.map { slot, alarm in (String(describing: slot.rawValue), alarm.rawValue) })
            rawValue["configuredAlerts"] = rawConfiguredAlerts
        }

        return rawValue
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        return [
            "### PodState",
            "* address: \(String(format: "%04X", address))",
            "* activatedAt: \(String(reflecting: activatedAt))",
            "* expiresAt: \(String(reflecting: expiresAt))",
            "* piVersion: \(piVersion)",
            "* pmVersion: \(pmVersion)",
            "* lot: \(lot)",
            "* tid: \(tid)",
            "* suspended: \(suspended)",
            "* unfinalizedBolus: \(String(describing: unfinalizedBolus))",
            "* unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))",
            "* unfinalizedSuspend: \(String(describing: unfinalizedSuspend))",
            "* unfinalizedResume: \(String(describing: unfinalizedResume))",
            "* finalizedDoses: \(String(describing: finalizedDoses))",
            "* activeAlerts: \(String(describing: activeAlerts))",
            "* messageTransportState: \(String(describing: messageTransportState))",
            "* setupProgress: \(setupProgress)",
            "* primeFinishTime: \(String(describing: primeFinishTime))",
            "* configuredAlerts: \(String(describing: configuredAlerts))",
            "",
            fault != nil ? String(reflecting: fault!) : "fault: nil",
            "",
            ].joined(separator: "\n")
    }
}

fileprivate struct NonceState: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]
    
    var table: [UInt32]
    var idx: UInt8
    
    public init(lot: UInt32 = 0, tid: UInt32 = 0, seed: UInt16 = 0) {
        table = Array(repeating: UInt32(0), count: 2 + 16)
        table[0] = (lot & 0xFFFF) &+ (lot >> 16) &+ 0x55543DC3
        table[1] = (tid & 0xFFFF) &+ (tid >> 16) &+ 0xAAAAE44E
        
        idx = 0
        
        table[0] += UInt32((seed & 0x00ff))
        table[1] += UInt32((seed & 0xff00) >> 8)
        
        for i in 0..<16 {
            table[2 + i] = generateEntry()
        }
        
        idx = UInt8((table[0] + table[1]) & 0x0F)
    }
    
    private mutating func generateEntry() -> UInt32 {
        table[0] = (table[0] >> 16) &+ ((table[0] & 0xFFFF) &* 0x5D7F)
        table[1] = (table[1] >> 16) &+ ((table[1] & 0xFFFF) &* 0x8CA0)
        return table[1] &+ ((table[0] & 0xFFFF) << 16)
    }
    
    public mutating func advanceToNextNonce() {
        let nonce = currentNonce
        table[Int(2 + idx)] = generateEntry()
        idx = UInt8(nonce & 0x0F)
    }
    
    public var currentNonce: UInt32 {
        return table[Int(2 + idx)]
    }
    
    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let table = rawValue["table"] as? [UInt32],
            let idx = rawValue["idx"] as? UInt8
            else {
                return nil
        }
        self.table = table
        self.idx = idx
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "table": table,
            "idx": idx,
        ]
        
        return rawValue
    }
}


