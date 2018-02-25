//
//  SetInsulinScheduleCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct SetInsulinScheduleCommand : MessageBlock {
    
//    2017-09-11T11:07:57.476872 ID1:1f08ced2 PTYPE:PDM SEQ:18 ID2:1f08ced2 B9:18 BLEN:31 MTYPE:1a0e BODY:bed2e16b02010a0101a000340034170d000208000186a0 CRC:fd
//    2017-09-11T11:07:57.552574 ID1:1f08ced2 PTYPE:ACK SEQ:19 ID2:1f08ced2 CRC:b8
//    2017-09-11T11:07:57.734557 ID1:1f08ced2 PTYPE:CON SEQ:20 CON:00000000000003c0 CRC:a9

    fileprivate enum ScheduleTypeCode: UInt8 {
        case basal = 0
        case tempBasal = 1
        case bolus = 2
    }

    public enum ScheduleEntry {
        case basal
        case tempBasal
        case bolus(units: Double, multiplier: UInt16)
        
        fileprivate func typeCode() -> ScheduleTypeCode {
            switch self {
            case .basal:
                return .basal
            case .tempBasal:
                return .tempBasal
            case .bolus:
                return .bolus
            }
        }
    }
    
    public let blockType: MessageBlockType = .setInsulinSchedule
    
    let nonce: UInt32
    let scheduleEntry: ScheduleEntry
    
    // 7ca8134d0200c401019000190019170d7c00fa00030d40
    
    // 1a 0e bed2e16b 02 010a 01 01a0 0034 0034 170d000208000186a0000000000000 03c0
    // 0  1  2        6  7    9  10   12   14
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            0x0e,
            ])
        data.append(contentsOf: nonce.bigEndian)
        data.append(scheduleEntry.typeCode().rawValue)
        switch scheduleEntry {
        case .basal:
            break // TODO
        case .tempBasal:
            break // TODO
        case .bolus(units: let units, multiplier: let multiplier):
            let duration = TimeInterval(minutes: 30)
            let unitRate = UInt16(units / 0.1 / duration.hours)
            let fieldA = unitRate * multiplier
            var bolusData = Data(bytes: [01])
            bolusData.append(contentsOf: fieldA.bigEndian)
            bolusData.append(contentsOf: unitRate.bigEndian)
            bolusData.append(contentsOf: unitRate.bigEndian)
            let checksum = calculateChecksum(bolusData)
            data.append(contentsOf: checksum.bigEndian)
            data.append(contentsOf: bolusData)
        }
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 6 {
            throw MessageBlockError.notEnoughData
        }
        //let length = encodedData[1]
        nonce = UInt32(bigEndian: encodedData.subdata(in: 2..<6))
        
        guard let scheduleTypeCode = ScheduleTypeCode(rawValue: encodedData[6]) else {
            throw MessageError.unknownValue(value: encodedData[6], typeDescription: "ScheduleTypeCode")
        }

        let checksum = UInt16(bigEndian: encodedData.subdata(in: 7..<9))
        let duration = TimeInterval(minutes: Double(encodedData[9] * 30))

        // These are placeholder names...
        let fieldA = UInt16(bigEndian: encodedData.subdata(in: 10..<12))
        let unitRate = UInt16(bigEndian: encodedData.subdata(in: 12..<14))
        //let unitRateSchedule = UInt32(bigEndian: encodedData.subdata(in: 14..<16))
        
        let calculatedChecksum: UInt16

        switch scheduleTypeCode {
        case .basal:
            scheduleEntry = .basal
            calculatedChecksum = 0x0 // TODO
        case .tempBasal:
            scheduleEntry = .tempBasal
            calculatedChecksum = 0x0 // TODO
        case .bolus:
            let units = Double(unitRate) * 0.1 * duration.hours
            calculatedChecksum = calculateChecksum(encodedData.subdata(in: 9..<16))
            scheduleEntry = .bolus(units: units, multiplier: fieldA / unitRate)
        }
        
        guard calculatedChecksum == checksum else {
            throw MessageError.validationFailed(description: "InsulinDeliverySchedule checksum failed")
        }
        
        // Do we need to check fieldA?  Wiki says fieldA = unitsRate * 0x10, but that's
        // not the case during prime, where it's unitsRate * 0x8 (or 1/2 of the normal case)
    }
    
    public init(nonce: UInt32, scheduleEntry: ScheduleEntry) {
        self.nonce = nonce
        self.scheduleEntry = scheduleEntry
    }
}

fileprivate func calculateChecksum(_ data: Data) -> UInt16 {
    return data.reduce(0) { $0 + UInt16($1) }
}

