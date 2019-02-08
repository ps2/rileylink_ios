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
    public let deliveryStatus: DeliveryStatus
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let totalInsulinDelivered: Double
    public let currentStatus: FaultEventCode
    public let faultEventTimeSinceActivation: TimeInterval?
    public let reservoirLevel: Double?
    public let timeActive: TimeInterval
    public let unacknowledgedAlerts: AlertSet
    public let faultAccessingTables: Bool
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
        
        self.deliveryStatus = DeliveryStatus(rawValue: encodedData[2] & 0xf)!
        
        self.insulinNotDelivered = Pod.pulseSize * Double((Int(encodedData[3] & 0x3) << 8) | Int(encodedData[4]))
        
        self.podMessageCounter = encodedData[5]
        
        self.totalInsulinDelivered = Pod.pulseSize * Double((Int(encodedData[6]) << 8) | Int(encodedData[7]))
        
        self.currentStatus = FaultEventCode(rawValue: encodedData[8])
        
        let minutesSinceActivation = encodedData[9...10].toBigEndian(UInt16.self)
        if minutesSinceActivation != 0xffff {
            self.faultEventTimeSinceActivation = TimeInterval(minutes: Double(minutesSinceActivation))
        } else {
            self.faultEventTimeSinceActivation = nil
        }
        
        let reservoirValue = Double((Int(encodedData[11] & 0x3) << 8) + Int(encodedData[12])) * Pod.pulseSize
        
        if reservoirValue <= Pod.maximumReservoirReading {
            self.reservoirLevel = reservoirValue
        } else {
            self.reservoirLevel =  nil
        }
        
        self.timeActive = TimeInterval(minutes: Double(encodedData[13...14].toBigEndian(UInt16.self)))
        
        self.unacknowledgedAlerts =  AlertSet(rawValue: encodedData[15])
        
        self.faultAccessingTables = encodedData[16] == 2
        
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
            "* rawHex: \(data.hexadecimalString)",
            "* podProgressStatus: \(podProgressStatus)",
            "* deliveryStatus: \(deliveryStatus.description)",
            "* insulinNotDelivered: \(insulinNotDelivered.twoDecimals) U",
            "* podMessageCounter: \(podMessageCounter)",
            "* totalInsulinDelivered: \(totalInsulinDelivered.twoDecimals) U",
            "* currentStatus: \(currentStatus.description)",
            "* faultEventTimeSinceActivation: \(faultEventTimeSinceActivation?.stringValue ?? "none")",
            "* reservoirLevel: \(reservoirLevel?.twoDecimals ?? "50+") U",
            "* timeActive: \(timeActive.stringValue)",
            "* unacknowledgedAlerts: \(unacknowledgedAlerts)",
            "* faultAccessingTables: \(faultAccessingTables)",
            "* logEventErrorType: \(logEventErrorType.description)",
            "* logEventErrorPodProgressStatus: \(logEventErrorPodProgressStatus)",
            "* receiverLowGain: \(receiverLowGain)",
            "* radioRSSI: \(radioRSSI)",
            "* previousPodProgressStatus: \(previousPodProgressStatus)",
            "* unknownValue: 0x\(unknownValue.hexadecimalString)",
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
        let timeComponent = String(format: "%02d:%02d", hours, minutes)
        if days > 0 {
            return String(format: "%d \(pluralFormOfDays) plus %@", days, timeComponent)
        } else {
            return timeComponent
        }
    }
}

extension Double {
    var twoDecimals: String {
        let reservoirLevel = self
        return String(format: "%.2f", reservoirLevel)
    }
}
