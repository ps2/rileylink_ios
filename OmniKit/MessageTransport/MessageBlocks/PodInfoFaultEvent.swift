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
    public let previousPodProgressStatus: PodProgressStatus
    public let recieverLowGain: UInt8
    public let radioRSSI: UInt8
    public let previousPodProgressStatusCheck: PodProgressStatus
    public let insulinStateTableCorruption: Bool
    public let immediateBolusInProgress: Bool
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < 19 {
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
        
        self.faultEventTimeSinceActivation = TimeInterval(seconds: Double(encodedData[9...10].toBigEndian(UInt16.self)))
        
        let resHighBits = Int(encodedData[11] & 0x03) << 6
        let resLowBits = Int(encodedData[12] >> 2)
        let reservoirValue = round(Double((resHighBits + resLowBits) * 50)/255)
        if reservoirValue < StatusResponse.maximumReservoirReading {
            reservoirLevel = reservoirValue
        } else {
            reservoirLevel = nil
        }
        self.timeActive = TimeInterval(minutes: Double((Int(encodedData[13] & 0b1) << 8) + Int(encodedData[14])))
        
        self.previousStatus = FaultEventCode(rawValue: encodedData[15])
        
        self.logEventError = encodedData[16] == 2

        self.insulinStateTableCorruption = encodedData[17] & 0b10000000 != 0
        
        guard let previousPodProgressStatus = PodProgressStatus(rawValue: encodedData[17] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[17] & 0xF, typeDescription: "PodProgressStatus")
        }
        
        self.immediateBolusInProgress = encodedData[17] & 0b00010000 != 0
        
        self.previousPodProgressStatus = previousPodProgressStatus
        
        self.recieverLowGain = encodedData[18] >> 4
        
        self.radioRSSI =  encodedData[18] & 0xF
        
        guard let previousPodProgressStatusCheck = PodProgressStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "PodProgressStatus")
        }
        self.previousPodProgressStatusCheck = previousPodProgressStatusCheck
        
        self.data = Data(encodedData)
    }
}

extension PodInfoFaultEvent: CustomDebugStringConvertible {
    public typealias RawValue = Data

    public func secondsToHoursMinutesSeconds (duration : Double) -> String {
        let interval = Int(duration)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    public var debugDescription: String {
        return [
            "## PodInfoFaultEvent",
            "rawHex: \(data.hexadecimalString)",
            "currentStatus: \(currentStatus)",
            "previousStatus: \(previousStatus)",
            "podProgressStatus: \(podProgressStatus)",
            "deliveryType: \(deliveryType)",
            "insulinNotDelivered: \(insulinNotDelivered)U",
            "unknownPageCode: \(unknownPageCode.hexadecimalString)",
            "faultEventTimeSinceActivation: \(faultEventTimeSinceActivation.stringValue)",
            "reservoirLevel: \(reservoirLevel ?? 50)U",
            "timeActive: \(timeActive.stringValue)",
            "logEventError: \(logEventError)",
            "previousPodProgressStatus: \(previousPodProgressStatus)",
            "recieverLowGain: \(recieverLowGain)",
            "radioRSSI: \(radioRSSI)",
            "previousPodProgressStatusCheck: \(previousPodProgressStatusCheck)",
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

extension TimeInterval {
    var stringValue: String {
        let seconds = Int(self) % 60
        let minutes = (seconds / 60) % 60
        let hours = (seconds / 3600)
        let days = (hours / 24)
        return String(format: "%d day(s), %02d:%02d:%02d", days, hours, minutes, seconds)
    }
}
