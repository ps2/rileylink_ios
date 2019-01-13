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
    
    public var needsCannulaInsertion: Bool {
        return self.rawValue < SetupProgress.cannulaInserting.rawValue
    }

    public var needsInitialBasalSchedule: Bool {
        return self.rawValue < SetupProgress.initialBasalScheduleSet.rawValue
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
    public var alerts: AlertSet
    public var lastInsulinMeasurements: PodInsulinMeasurements?
    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?
    var finalizedDoses: [UnfinalizedDose]
    public private(set) var suspended: Bool
    public var fault: PodInfoFaultEvent?
    public var messageTransportState: MessageTransportState
    public var primeFinishTime: Date?
    public var setupProgress: SetupProgress
    //var registeredAlerts: [AlertSlot: ]
    
    public var deliveryScheduleUncertain: Bool {
        return unfinalizedBolus?.scheduledCertainty == .uncertain || unfinalizedTempBasal?.scheduledCertainty == .uncertain
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
        self.unfinalizedBolus = nil
        self.unfinalizedTempBasal = nil
        self.finalizedDoses = []
        self.suspended = false
        self.fault = nil
        self.alerts = .none
        self.messageTransportState = MessageTransportState(packetNumber: 0, messageNumber: 0)
        self.primeFinishTime = nil
        self.setupProgress = .addressAssigned
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
        nonceState = NonceState(lot: lot, tid: tid, seed: UInt8(seed & 0xff))
    }
    
    public mutating func updateFromStatusResponse(_ response: StatusResponse) {
        updateDeliveryStatus(deliveryStatus: response.deliveryStatus)
        lastInsulinMeasurements = PodInsulinMeasurements(statusResponse: response, validTime: Date())
        alerts = response.alerts
    }
    
    private mutating func updateDeliveryStatus(deliveryStatus: StatusResponse.DeliveryStatus) {
        let now = Date()
        
        if let bolus = unfinalizedBolus {
            if bolus.finishTime <= now {
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

        if let tempBasal = unfinalizedTempBasal {
            if tempBasal.finishTime <= now {
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
        
        suspended = deliveryStatus == .suspended
    }

    // MARK: - RawRepresentable
    public init?(rawValue: RawValue) {

        guard
            let address = rawValue["address"] as? UInt32,
            let nonceStateRaw = rawValue["nonceState"] as? NonceState.RawValue,
            let nonceState = NonceState(rawValue: nonceStateRaw),
            let activatedAt = rawValue["activatedAt"] as? Date,
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
        
        if let expiresAt = rawValue["expiresAt"] as? Date {
            self.expiresAt = expiresAt
        } else {
            self.expiresAt = activatedAt.addingTimeInterval(podSoftExpirationTime)
        }
        
        if let alarmsRawValue = rawValue["alerts"] as? UInt8 {
            self.alerts = AlertSet(rawValue: alarmsRawValue)
        } else {
            self.alerts = .none
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
            "alerts": alerts.rawValue,
            "messageTransportState": messageTransportState.rawValue,
            "setupProgress": setupProgress.rawValue
            ]
        
        if let unfinalizedBolus = self.unfinalizedBolus {
            rawValue["unfinalizedBolus"] = unfinalizedBolus.rawValue
        }
        
        if let unfinalizedTempBasal = self.unfinalizedTempBasal {
            rawValue["unfinalizedTempBasal"] = unfinalizedTempBasal.rawValue
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
            "* finalizedDoses: \(String(describing: finalizedDoses))",
            "* alerts: \(String(describing: alerts))",
            "* messageTransportState: \(String(describing: messageTransportState))",
            "* setupProgress: \(setupProgress)",
            "* primeFinishTime: \(String(describing: primeFinishTime))",
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
    
    public init(lot: UInt32 = 0, tid: UInt32 = 0, seed: UInt8 = 0) {
        table = Array(repeating: UInt32(0), count: 21)
        table[0] = (lot & 0xFFFF) + 0x55543DC3 + (lot >> 16)
        table[0] = table[0] & 0xFFFFFFFF
        table[1] = (tid & 0xFFFF) + 0xAAAAE44E + (tid >> 16)
        table[1] = table[1] & 0xFFFFFFFF
        
        idx = 0
        
        table[0] += UInt32(seed)
        
        for i in 0..<16 {
            table[2 + i] = generateEntry()
        }
        
        idx = UInt8((table[0] + table[1]) & 0x0F)
    }
    
    private mutating func generateEntry() -> UInt32 {
        table[0] = ((table[0] >> 16) + (table[0] & 0xFFFF) * 0x5D7F) & 0xFFFFFFFF
        table[1] = ((table[1] >> 16) + (table[1] & 0xFFFF) * 0x8CA0) & 0xFFFFFFFF
        return UInt32((UInt64(table[1]) + (UInt64(table[0]) << 16)) & 0xFFFFFFFF)
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


