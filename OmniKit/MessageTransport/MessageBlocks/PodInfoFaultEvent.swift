//
//  PodInfoFaultEvent.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFaultEvent : PodInfo, Equatable {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
        
    public var podInfoType: PodInfoResponseSubType = .faultEvents
    public let reservoirStatus: ReservoirStatus
    public let deliveryType: DeliveryType
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let unknownPageCode: Double
    public let originalLoggedFaultEvent: FaultEventCode
    public let faultEventTimeSinceActivation: Double
    public let insulinRemaining: Double
    public let timeActive: TimeInterval
    public let secondaryLoggedFaultEvent: FaultEventCode
    public let logEventError: Bool
    public let reservoirStatusAtFirstLoggedFaultEvent: ReservoirStatus
    public let receiverLowGain: Int8
    public let radioRSSI: Int8
    public let reservoirStatusAtFirstLoggedFaultEventCheck: ReservoirStatus
    public let insulinStateTableCorruption: Bool
    public let immediateBolusInProgress: Bool
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 19 {
            throw MessageBlockError.notEnoughData
        }
        
        guard let reservoirStatus = ReservoirStatus(rawValue: encodedData[1]) else {
            throw MessageError.unknownValue(value: encodedData[1], typeDescription: "ReservoirStatus")
        }
        self.reservoirStatus = reservoirStatus
        
        self.deliveryType = DeliveryType(rawValue: encodedData[2] & 0xf)
        
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[3] & 0x3) << 8) | Int(encodedData[4]))
        
        self.podMessageCounter = encodedData[5]
        self.unknownPageCode = Double(Int(encodedData[6]) | Int(encodedData[7]))
        
        self.originalLoggedFaultEvent = FaultEventCode(rawValue: encodedData[8])
        
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double((Int(encodedData[9] & 0b1) << 8) + Int(encodedData[10])))
        
        self.insulinRemaining = podPulseSize * Double((Int(encodedData[11] & 0x3) << 8) | Int(encodedData[12]))
        
        self.timeActive = TimeInterval(minutes: Double((Int(encodedData[13] & 0b1) << 8) + Int(encodedData[14])))
        
        self.secondaryLoggedFaultEvent = FaultEventCode(rawValue: encodedData[15])
        
        self.logEventError = encodedData[16] == 2

        self.insulinStateTableCorruption = encodedData[17] & 0b10000000 != 0
        
        guard let reservoirStatusAtFirstLoggedFaultEventType = ReservoirStatus(rawValue: encodedData[17] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[17] & 0xF, typeDescription: "ReservoirStatus")
        }
        
        self.immediateBolusInProgress = encodedData[17] & 0b00010000 != 0
        
        self.reservoirStatusAtFirstLoggedFaultEvent = reservoirStatusAtFirstLoggedFaultEventType
        
        self.receiverLowGain = Int8(encodedData[18] >> 6)
        
        self.radioRSSI =  Int8(encodedData[18] & 0x3F)
        
        guard let reservoirStatusAtFirstLoggedFaultEventCheckType = ReservoirStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "ReservoirStatus")
        }
        self.reservoirStatusAtFirstLoggedFaultEventCheck = reservoirStatusAtFirstLoggedFaultEventCheckType
        
        self.data = Data(encodedData)
    }
}

extension PodInfoFaultEvent: CustomDebugStringConvertible {
    public typealias RawValue = Data

    public var debugDescription: String {
        return [
            "## PodInfoFaultEvent",
            "rawHex: \(data.hexadecimalString)",
            "originalLoggedFaultEvent: \(originalLoggedFaultEvent)",
            "secondaryLoggedFaultEvent: \(secondaryLoggedFaultEvent)",
            "reservoirStatus: \(reservoirStatus)",
            "deliveryType: \(deliveryType)",
            "insulinNotDelivered: \(insulinNotDelivered)",
            "unknownPageCode: \(unknownPageCode)",
            "faultEventTimeSinceActivation: \(faultEventTimeSinceActivation)",
            "insulinRemaining: \(insulinRemaining)",
            "timeActive: \(timeActive)",
            "logEventError: \(logEventError)",
            "reservoirStatusAtFirstLoggedFaultEvent: \(reservoirStatusAtFirstLoggedFaultEvent)",
            "receiverLowGain: \(receiverLowGain)",
            "radioRSSI: \(radioRSSI)",
            "reservoirStatusAtFirstLoggedFaultEventCheck: \(reservoirStatusAtFirstLoggedFaultEventCheck)",
            "insulinStateTableCorruption: \(insulinStateTableCorruption)",
            "immediateBolusInProgress: \(immediateBolusInProgress)",
            "",
            ].joined(separator: "\n")
    }
}

extension PodInfoFaultEvent: RawRepresentable {
    public init?(rawValue: Data) {
        do {
            try self.init(encodedData: rawValue)
        } catch {
            return nil
        }
    }
    
    public var rawValue: Data {
        return data
    }
}
