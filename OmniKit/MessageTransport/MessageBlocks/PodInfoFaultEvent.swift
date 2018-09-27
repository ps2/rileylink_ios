//
//  PodInfoFaultEvent.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFaultEvent : PodInfo {
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

    public var podInfoType              : PodInfoResponseSubType = .faultEvents
    public let reservoirStatus          : StatusResponse.ReservoirStatus
    public let deliveryInProgressType   : DeliveryInProgressType
    public let insulinNotDelivered      : Double
    public let podMessageCounter        : UInt8
    public let unknownPageCode          : Double
    public let originalLoggedFaultEvent : PodInfoResponseSubType.FaultEventType
    public let faultEventTimeSinceActivation: Double
    public let insulinRemaining         : Double
    public let timeActive               : TimeInterval
    public let secondaryLoggedFaultEvent: PodInfoResponseSubType.FaultEventType
    public let logEventError            : Bool
    public let infoLoggedFaultEvent     : InfoLoggedFaultEventType
    public let reservoirStatusAtFirstLoggedFaultEvent: StatusResponse.ReservoirStatus
    public let recieverLowGain          : UInt8
    public let radioRSSI                : UInt8
    public let reservoirStatusAtFirstLoggedFaultEventCheck: StatusResponse.ReservoirStatus
    
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(19) {
            throw MessageBlockError.notEnoughData
        }
        
        guard let reservoirStatus = StatusResponse.ReservoirStatus(rawValue: encodedData[1]) else {
            throw MessageError.unknownValue(value: encodedData[1], typeDescription: "StatusResponse.ReservoirStatus")
        }
        self.reservoirStatus = reservoirStatus
        
        self.deliveryInProgressType = DeliveryInProgressType(rawValue: encodedData[2] & 0xf)
        
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[3] & 0x3) << 8) | Int(encodedData[4]))
        
        self.podMessageCounter = encodedData[5]
        self.unknownPageCode = Double(Int(encodedData[6]) | Int(encodedData[7]))
        
        self.originalLoggedFaultEvent = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[8])!
        
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double((Int(encodedData[9] & 0b1) << 8) + Int(encodedData[10])))
        
        self.insulinRemaining = podPulseSize * Double((Int(encodedData[11] & 0x3) << 8) | Int(encodedData[12]))
        
        self.timeActive = TimeInterval(minutes: Double((Int(encodedData[13] & 0b1) << 8) + Int(encodedData[14])))
        
        self.secondaryLoggedFaultEvent = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[15])!
        
        self.logEventError = encodedData[16] == 2

        guard let infoLoggedFaultEventType = InfoLoggedFaultEventType(rawValue: encodedData[17] >> 4) else {
            throw MessageError.unknownValue(value: encodedData[17] >> 4, typeDescription: "InfoLoggedFaultEventType")
        }
        self.infoLoggedFaultEvent = infoLoggedFaultEventType
        
        guard let reservoirStatusAtFirstLoggedFaultEventType = StatusResponse.ReservoirStatus(rawValue: encodedData[17] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[17] & 0xF, typeDescription: "ProgressType")
        }
        self.reservoirStatusAtFirstLoggedFaultEvent = reservoirStatusAtFirstLoggedFaultEventType
        
        self.recieverLowGain = encodedData[18] >> 4
        
        self.radioRSSI =  encodedData[18] & 0xF
        
        guard let reservoirStatusAtFirstLoggedFaultEventCheckType = StatusResponse.ReservoirStatus(rawValue: encodedData[19] & 0xF) else {
            throw MessageError.unknownValue(value: encodedData[19] & 0xF, typeDescription: "ProgressType")
        }
        self.reservoirStatusAtFirstLoggedFaultEventCheck = reservoirStatusAtFirstLoggedFaultEventCheckType
        
        self.data = Data(encodedData)
    }
}
