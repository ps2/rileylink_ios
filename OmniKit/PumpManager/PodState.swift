//
//  PodState.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodState: RawRepresentable, Equatable, CustomDebugStringConvertible {
    
    public typealias RawValue = [String: Any]
    
    public let address: UInt32
    fileprivate var nonceState: NonceState
    public let activatedAt: Date
    public var timeZone: TimeZone
    public let piVersion: String
    public let pmVersion: String
    public let lot: UInt32
    public let tid: UInt32
    public var lastInsulinMeasurements: PodInsulinMeasurements?
    var unfinalizedBolus: UnfinalizedDose?
    var unfinalizedTempBasal: UnfinalizedDose?
    var finalizedDoses: [UnfinalizedDose]
    
    public var expiresAt: Date {
        return activatedAt + .days(3)
    }
    
    public var deliveryScheduleUncertain: Bool {
        return unfinalizedBolus?.scheduledCertainty == .uncertain || unfinalizedTempBasal?.scheduledCertainty == .uncertain
    }
    
    public init(address: UInt32, activatedAt: Date, timeZone: TimeZone, piVersion: String, pmVersion: String, lot: UInt32, tid: UInt32) {
        self.address = address
        self.nonceState = NonceState(lot: lot, tid: tid)
        self.activatedAt = activatedAt
        self.timeZone = timeZone
        self.piVersion = piVersion
        self.pmVersion = pmVersion
        self.lot = lot
        self.tid = tid
        self.lastInsulinMeasurements = nil
        self.unfinalizedBolus = nil
        self.unfinalizedTempBasal = nil
        self.finalizedDoses = []
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
    
    public mutating func finalizeDoses(deliveryStatus: StatusResponse.DeliveryStatus) {
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
    }

    // MARK: - RawRepresentable
    public init?(rawValue: RawValue) {

        guard
            let address = rawValue["address"] as? UInt32,
            let nonceStateRaw = rawValue["nonceState"] as? NonceState.RawValue,
            let nonceState = NonceState(rawValue: nonceStateRaw),
            let activatedAt = rawValue["activatedAt"] as? Date,
            let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds),
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
        self.timeZone = timeZone
        self.piVersion = piVersion
        self.pmVersion = pmVersion
        self.lot = lot
        self.tid = tid

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
        
        if let rawLastInsulinMeasurements = rawValue["lastInsulinMeasurements"] as? PodInsulinMeasurements.RawValue
        {
            self.lastInsulinMeasurements = PodInsulinMeasurements(rawValue: rawLastInsulinMeasurements)
        } else {
            self.lastInsulinMeasurements = nil
        }
        
        if let rawFinalizedDoses = rawValue["finalizedDoses"] as? [UnfinalizedDose.RawValue]
        {
            self.finalizedDoses = rawFinalizedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finalizedDoses = []
        }

    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "address": address,
            "nonceState": nonceState.rawValue,
            "activatedAt": activatedAt,
            "timeZone": timeZone.secondsFromGMT(),
            "piVersion": piVersion,
            "pmVersion": pmVersion,
            "lot": lot,
            "tid": tid,
            "finalizedDoses": finalizedDoses.map( { $0.rawValue })
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

        return rawValue
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        return [
            "## PodState",
            "address: \(String(format: "%04X", address))",
            "activatedAt: \(String(reflecting: activatedAt))",
            "timeZone: \(timeZone)",
            "piVersion: \(piVersion)",
            "pmVersion: \(pmVersion)",
            "lot: \(lot)",
            "tid: \(tid)",
            "unfinalizedBolus: \(String(describing: unfinalizedBolus))",
            "unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))",
            "finalizedDoses: \(String(describing: finalizedDoses))",
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


