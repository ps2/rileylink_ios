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
    public let podProgressStatus: PodProgressStatus
    public let deliveryType: DeliveryType
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let unknownPageCode: Data
    public let previousStatus: FaultEventCode
    public let currentStatus: FaultEventCode
    public let faultEventTimeSinceActivation: TimeInterval
    public let reservoirLevel: Double?
    public let timeActive: TimeInterval
    public let logEventError: Bool
    public let logEventErrorType: LogEventErrorCode
    public let logEventErrorPodProgressStatus: PodProgressStatus
    public let receiverLowGain: Int8
    public let radioRSSI: Int8
    public let previousPodProgressStatus: PodProgressStatus
    public let unknownValue: Data
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 21 {
            throw MessageBlockError.notEnoughData
        }
        
        guard PodProgressStatus(rawValue: encodedData[1]) != nil else {
            throw MessageError.unknownValue(value: encodedData[1], typeDescription: "PodProgressStatus")
        }
        self.podProgressStatus = PodProgressStatus(rawValue: encodedData[1])!
        
        self.deliveryType = DeliveryType(rawValue: encodedData[2] & 0xf)
        
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[3] & 0x3) << 8) | Int(encodedData[4]))
        
        self.podMessageCounter = encodedData[5]
        self.unknownPageCode = encodedData[6...7]
        
        self.currentStatus = FaultEventCode(rawValue: encodedData[8])
        
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double(encodedData[9...10].toBigEndian(UInt16.self)))
        
        let reservoirValue = Double((Int(encodedData[11] & 0x3) << 8) + Int(encodedData[12])) * podPulseSize
        
        if reservoirValue <= StatusResponse.maximumReservoirReading {
            self.reservoirLevel = reservoirValue
        } else {
            self.reservoirLevel = nil
        }
        
        self.timeActive = TimeInterval(minutes: Double(encodedData[13...14].toBigEndian(UInt16.self)))
        
        self.previousStatus = FaultEventCode(rawValue: encodedData[15])
        
        self.logEventError = encodedData[16] == 2

        self.logEventErrorType = LogEventErrorCode(rawValue: encodedData[17] >> 4)
        
        guard let logEventErrorPodProgressStatus = PodProgressStatus(rawValue: encodedData[17] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[17] & 0xF, typeDescription: "PodProgressStatus")
        }
        self.logEventErrorPodProgressStatus = logEventErrorPodProgressStatus
        
        self.receiverLowGain = Int8(encodedData[18] >> 6)
        
        self.radioRSSI =  Int8(encodedData[18] & 0x3F)
        
        guard let previousPodProgressStatus = PodProgressStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "PodProgressStatus")
        }
        self.previousPodProgressStatus = previousPodProgressStatus
        
        self.unknownValue = encodedData[20...21]
        
        self.data = Data(encodedData)
    }
}

extension PodInfoFaultEvent: CustomDebugStringConvertible {
    public typealias RawValue = Data
    public var debugDescription: String {
        return [
            "## PodInfoFaultEvent",
            "rawHex: \(data.hexadecimalString)",
            "currentStatus: \(currentStatus.description)",
            "previousStatus: \(previousStatus.description)",
            "podProgressStatus: \(podProgressStatus)",
            "deliveryType: \(deliveryType.description)",
            "podProgressStatus: \(podProgressStatus)",
            "reservoirLevel: \(String(describing: reservoirLevel)) U",
            "timeActive: \(timeActive.stringValue)",
            "logEventError: \(logEventError)",
            "logEventErrorType: \(logEventErrorType.description)",
            "logEventErrorPodProgressStatus: \(logEventErrorPodProgressStatus)",
            "recieverLowGain: \(receiverLowGain)",
            "radioRSSI: \(radioRSSI)",
            "recieverLowGain: \(receiverLowGain)",
            "previousPodProgressStatus: \(previousPodProgressStatus)",
            "unknownValue: \(unknownValue.hexadecimalString)",
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

extension TimeInterval {
    var stringValue: String {
        let totalSeconds = self
        let minutes = Int(totalSeconds / 60) % 60
        let hours = Int(totalSeconds / 3600) - (Int(self / 3600)/24 * 24)
        let days = Int((totalSeconds / 3600) / 24)
        var pluralFormOfDays = "days"
        if days == 1 {
            pluralFormOfDays = "day"
        }
        return String(format: "%d \(pluralFormOfDays) plus %02d:%02d", days, hours, minutes)
    }
}
