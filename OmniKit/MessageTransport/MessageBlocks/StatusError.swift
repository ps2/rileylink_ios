//
//  StatusError.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusError : MessageBlock {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    
//    public enum lengthType: UInt8{
//        case normal = 0x10
//        case configuredAlerts = 0x13
//        case faultEvents = 0x16
//        case dataLog = 0x04*numberOfWords+0x08
//        case faultDataInitializationTime = 0x11
//        case hardcodedValues  = 0x5
//        case resetStatus = numberOfBytes & 0x03
//        case dumpRecentFlashLog = 0x13
//        case dumpOlderFlashlog = 0x14
//
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10


    public struct DeliveryInProgressType: OptionSet {
        public let rawValue: UInt8
        
        static let none          = DeliveryInProgressType(rawValue: 0)
        static let basal         = DeliveryInProgressType(rawValue: 1 << 0)
        static let tempBasal     = DeliveryInProgressType(rawValue: 1 << 1)
        static let bolus         = DeliveryInProgressType(rawValue: 1 << 2)
        static let extendedBolus = DeliveryInProgressType(rawValue: 1 << 3)
        
        static let all: DeliveryInProgressType = [.none, .basal, .tempBasal, .bolus, .extendedBolus]
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
    
    public enum InfoLoggedFaultEventType: UInt8 {
        case insulinStateCorruptionDuringErrorLogging = 0
        case immediateBolusInProgressDuringError = 1
        // TODO: bb: internal boolean variable initialized to Tab5[$D] != 0
    }
    
    public let requestedType: GetStatusCommand.StatusType
    public let length: UInt8
    public let blockType: MessageBlockType = .statusError
    public let deliveryInProgressType: DeliveryInProgressType
    public let reservoirStatus: StatusResponse.ReservoirStatus  // Reused from StatusResponse
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let unknownPageCode: Double
    public let originalLoggedFaultEvent: UInt8
    public let faultEventTimeSinceActivation: Double
    public let insulinRemaining: Double
    public let timeActive: TimeInterval
    public let secondaryLoggedFaultEvent: UInt8
    public let logEventError: Bool
    public let infoLoggedFaultEvent: InfoLoggedFaultEventType
    public let reservoirStatusAtFirstLoggedFaultEvent: StatusResponse.ReservoirStatus
    public let recieverLowGain: UInt8
    public let radioRSSI: UInt8
    public let reservoirStatusAtFirstLoggedFaultEventCheck: StatusResponse.ReservoirStatus

    public let data: Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(13) {
            throw MessageBlockError.notEnoughData
        }
        
        self.length = encodedData[1]
 
        guard let requestedType = GetStatusCommand.StatusType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "StatusType")
        }
        self.requestedType = requestedType

        guard let reservoirStatus = StatusResponse.ReservoirStatus(rawValue: encodedData[3]) else {
            throw MessageError.unknownValue(value: encodedData[3], typeDescription: "StatusResponse.ReservoirStatus")
        }
        self.reservoirStatus = reservoirStatus

        self.deliveryInProgressType = DeliveryInProgressType(rawValue: encodedData[4] & 0xf)

        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[5] & 0x3) << 8) | Int(encodedData[6]))
        
        self.podMessageCounter = encodedData[7]
        self.unknownPageCode = Double(Int(encodedData[8]) | Int(encodedData[9]))
        
        self.originalLoggedFaultEvent = encodedData[10]
        
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double((Int(encodedData[11] & 0b1) << 8) + Int(encodedData[12])))
        
        self.insulinRemaining = podPulseSize * Double((Int(encodedData[13] & 0x3) << 8) | Int(encodedData[14]))
        
        self.timeActive = TimeInterval(minutes: Double((Int(encodedData[15] & 0b1) << 8) + Int(encodedData[16])))
        
        self.secondaryLoggedFaultEvent = encodedData[17]

        self.logEventError = encodedData[18] == 2

        guard let infoLoggedFaultEventType = InfoLoggedFaultEventType(rawValue: encodedData[19] >> 4) else {
            throw MessageError.unknownValue(value: encodedData[19] >> 4, typeDescription: "InfoLoggedFaultEventType")
        }
        self.infoLoggedFaultEvent = infoLoggedFaultEventType
        
        guard let reservoirStatusAtFirstLoggedFaultEventType = StatusResponse.ReservoirStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "ProgressType")
        }
        self.reservoirStatusAtFirstLoggedFaultEvent = reservoirStatusAtFirstLoggedFaultEventType
        
        self.recieverLowGain = encodedData[20] >> 4
        
        self.radioRSSI =  encodedData[20] & 0xF
        
        guard let reservoirStatusAtFirstLoggedFaultEventCheckType = StatusResponse.ReservoirStatus(rawValue: encodedData[21] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[21] & 0xF, typeDescription: "ProgressType")
        }
        self.reservoirStatusAtFirstLoggedFaultEventCheck = reservoirStatusAtFirstLoggedFaultEventCheckType
        
        // Unknown value:
        self.data = Data(encodedData[22])
    }
}
