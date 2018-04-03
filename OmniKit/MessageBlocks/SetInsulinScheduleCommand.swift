//
//  SetInsulinScheduleCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct SetInsulinScheduleCommand : MessageBlock {
    
    private static let pulseSize: Double = 0.05

    
    fileprivate enum ScheduleTypeCode: UInt8 {
        case basalSchedule = 0
        case tempBasal = 1
        case bolus = 2
    }
    
    public struct BasalScheduleEntry {
        let segments: Int
        let pulses: Int
        let alternateSegmentPulse: Bool
        
        public init(encodedData: Data) {
            segments = Int(encodedData[0] >> 4) + 1
            pulses = Int(encodedData[1])
            alternateSegmentPulse = (encodedData[0] >> 3) & 0x1 == 1
        }
        
        public init(segments: Int, pulses: Int, alternateSegmentPulse: Bool) {
            self.segments = segments
            self.pulses = pulses
            self.alternateSegmentPulse = alternateSegmentPulse
        }
        
        public var data: Data {
            return Data(bytes: [
                UInt8((segments - 1) << 4) + UInt8((alternateSegmentPulse ? 1 : 0) << 3),
                UInt8(pulses)
                ])
        }
        
        public func totalPulses() -> UInt16 {
            return UInt16(pulses) * UInt16(segments) + UInt16(alternateSegmentPulse ? segments / 2 : 0)
        }
    }

    public enum DeliverySchedule {
        case basalSchedule(currentSegment: UInt8, secondsRemaining: UInt16, pulsesRemaining: UInt16, entries: [BasalScheduleEntry])
        case tempBasal
        // During prime, multiplier is 8, otherwise 16 (0x10)
        case bolus(units: Double, multiplier: UInt16)
        
        fileprivate func typeCode() -> ScheduleTypeCode {
            switch self {
            case .basalSchedule:
                return .basalSchedule
            case .tempBasal:
                return .tempBasal
            case .bolus:
                return .bolus
            }
        }
        
        fileprivate var data: Data {
            switch self {
            case .basalSchedule(let currentSegment, let secondsRemaining, let pulsesRemaining, let entries):
                var data = Data(bytes: [currentSegment])
                data.appendBigEndian(secondsRemaining << 3)
                data.appendBigEndian(pulsesRemaining)
                for entry in entries {
                    data.append(entry.data)
                }
                return data
            case .bolus(let units, let multiplier):
                let pulseCount = UInt16(units / pulseSize)
                let fieldA = pulseCount * multiplier
                let numHalfHourSegments: UInt8 = 1
                var data = Data(bytes: [numHalfHourSegments])
                data.appendBigEndian(fieldA)
                data.appendBigEndian(pulseCount)
                data.appendBigEndian(pulseCount)
                return data
            case .tempBasal:
                return Data()
            }
        }
        
        fileprivate func checksum() -> UInt16 {
            switch self {
            case .basalSchedule( _, _, _, let entries):
                return data[0..<5].reduce(0) { $0 + UInt16($1) } +
                    entries.reduce(0) { $0 + $1.totalPulses() }
            case .bolus:
                return data[0..<7].reduce(0) { $0 + UInt16($1) }
            case .tempBasal:
                return 0x0
            }
        }
    }
    
    public let blockType: MessageBlockType = .setInsulinSchedule
    
    public let nonce: UInt32
    public let deliverySchedule: DeliverySchedule
    
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(7 + deliverySchedule.data.count),
            ])
        data.appendBigEndian(nonce)
        data.append(deliverySchedule.typeCode().rawValue)
        data.appendBigEndian(deliverySchedule.checksum())
        data.append(deliverySchedule.data)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 6 {
            throw MessageBlockError.notEnoughData
        }
        let length = encodedData[1]
        
        nonce = encodedData[2...].toBigEndian(UInt32.self)
        
        let checksum = encodedData[7...].toBigEndian(UInt16.self)

        guard let scheduleTypeCode = ScheduleTypeCode(rawValue: encodedData[6]) else {
            throw MessageError.unknownValue(value: encodedData[6], typeDescription: "ScheduleTypeCode")
        }

        switch scheduleTypeCode {
        case .basalSchedule:
            var entries = [BasalScheduleEntry]()
            let numEntries = (length - 12) / 2
            for i in 0..<numEntries {
                let dataStart = Int(i*2 + 14)
                let entryData = encodedData.subdata(in: dataStart..<(dataStart+2))
                entries.append(BasalScheduleEntry(encodedData: entryData))
            }
            let currentTableIndex = encodedData[9]
            let secondsRemaining = encodedData[10...].toBigEndian(UInt16.self) >> 3
            let pulsesRemaining = encodedData[12...].toBigEndian(UInt16.self)
            deliverySchedule = .basalSchedule(currentSegment: currentTableIndex, secondsRemaining: secondsRemaining, pulsesRemaining: pulsesRemaining, entries: entries)
        case .tempBasal:
            deliverySchedule = .tempBasal
        case .bolus:
            let duration = TimeInterval(minutes: Double(encodedData[9] * 30))
            let fieldA = encodedData[10...].toBigEndian(UInt16.self)
            let unitRate = encodedData[12...].toBigEndian(UInt16.self)
            let units = Double(unitRate) * 0.1 * duration.hours
            deliverySchedule = .bolus(units: units, multiplier: fieldA / unitRate)
        }
        
        guard checksum == deliverySchedule.checksum() else {
            throw MessageError.validationFailed(description: "InsulinDeliverySchedule checksum failed")
        }
    }
    
    public init(nonce: UInt32, deliverySchedule: DeliverySchedule) {
        self.nonce = nonce
        self.deliverySchedule = deliverySchedule
    }
}

fileprivate func calculateChecksum(_ data: Data) -> UInt16 {
    return data.reduce(0) { $0 + UInt16($1) }
}

