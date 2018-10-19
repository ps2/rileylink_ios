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
    public let reservoirLevel: String
    public let timeActive: TimeInterval
    public let logEventError: Bool
    public let logEventErrorType: LogEventErrorType
    public let logEventErrorPodProgressStatus: PodProgressStatus
    public let receiverLowGain: Int8
    public let radioRSSI: Int8
    public let previousPodProgressStatus: PodProgressStatus
    public let unKnownValue: Data
    public let data: Data
    
    public enum LogEventErrorType: UInt8, CustomStringConvertible {
        case none                                                     = 0b0000
        case immediateBolusInProgress                                 = 0b0001
        case internal2BitVariableSetAndManipulatedInMainLoopRoutines2 = 0b0010
        case internal2BitVariableSetAndManipulatedInMainLoopRoutines3 = 0b0100
        case insulinStateTableCorruption                              = 0b1000
        
        public var description: String {
            switch self {
                case .none:
                    return "None"
                case .immediateBolusInProgress:
                    return "Immediate Bolus In Progress"
                case .internal2BitVariableSetAndManipulatedInMainLoopRoutines2:
                    return "Internal 2-Bit Variable Set And Manipulated In Main Loop Routines 0x02"
                case .internal2BitVariableSetAndManipulatedInMainLoopRoutines3:
                    return "Internal 2-Bit Variable Set And Manipulated In Main Loop Routines 0x03"
                case .insulinStateTableCorruption:
                    return "Insulin State Table Corruption"
            }
        }        
    }
    
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
        
        self.faultEventTimeSinceActivation = TimeInterval(seconds: Double(encodedData[9...10].toBigEndian(UInt16.self)))
        
        let resHighBits = Int(encodedData[11] & 0x03) << 6
        let resLowBits = Int(encodedData[12] >> 2)
        let reservoirValue = round(Double((resHighBits + resLowBits) * 50)/255)
        if reservoirValue < StatusResponse.maximumReservoirReading {
            reservoirLevel = "\(reservoirValue) U"
        } else {
            reservoirLevel = ">50 U"
        }
        
        self.timeActive = TimeInterval(seconds: Double(encodedData[13...14].toBigEndian(UInt16.self)))
        
        self.previousStatus = FaultEventCode(rawValue: encodedData[15])
        
        self.logEventError = encodedData[16] == 2

        guard let logEventErrorType = LogEventErrorType(rawValue:encodedData[17] >> 4) else {
            throw MessageError.unknownValue(value: encodedData[17] >> 4, typeDescription: "LogEventErrorType")
        }
        self.logEventErrorType = logEventErrorType
        
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
        
        self.unKnownValue = encodedData[20...21]
        
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
            "reservoirLevel: \(reservoirLevel)",
            "timeActive: \(timeActive.stringValue)",
            "logEventError: \(logEventError)",
            "logEventErrorType: \(logEventErrorType.description)",
            "logEventErrorPodProgressStatus: \(logEventErrorPodProgressStatus)",
            "recieverLowGain: \(receiverLowGain)",
            "radioRSSI: \(radioRSSI)",
            "recieverLowGain: \(receiverLowGain)",
            "previousPodProgressStatus: \(previousPodProgressStatus)",
            "unKnownValue: \(unKnownValue)",
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
        return String(format: "%d day == 1 ? “” : “s”, %02d:%02d:%02d", days, hours, minutes, seconds)
    }
}
