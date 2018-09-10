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
//        case dumpOlderFlashlog = 0x13
//
    // public let numberOfWords: UInt8 = 60
    // public let numberOfBytes: UInt8 = 10

    public enum ProgressType: UInt8 {
        case intitialized = 0
        case tankPowerActivated = 1
        case tankFillCompleted = 2
        case pairingSuccess = 3
        case Purging = 4
        case readyForInjection = 5
        case injectionDone = 6
        case primingCannula = 7
        case runningNormal = 8
        case runningLessThen50ULeftInReservoir = 9
        case OnenotUsedButin33 = 10
        case TwonotUsedButin33 = 11
        case TheenotUsedButin33 = 12
        case errorEventLoggedShuttingDown = 13
        case alertExpiredDuringInitializationShuttingDown = 14
        case podInactive = 15  // ($1C Deactivate Pod or packet header mismatch)
    }

    public enum DeliveryInProgressType: UInt8 {
        case basal = 1
        case tembasal = 2
        case bolus = 4
        case extendedbolus = 8
    }
    
    public let requestedType: GetStatusCommand.StatusType
    public let length: UInt8
    public let blockType: MessageBlockType = .statusError
    public let progressType: ProgressType
    public let deliveryInProgressType: DeliveryInProgressType
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let unknownPageCode: Double
    public let origionalLoggedFaultEvent: UInt8
    public let faultEventTimeSinceActivation: Double
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

        guard let progressType = ProgressType(rawValue: encodedData[3]) else {
            throw MessageError.unknownValue(value: encodedData[3], typeDescription: "ProgressType")
        }
        self.progressType = progressType

        guard let deliveryInProgressType = DeliveryInProgressType(rawValue: encodedData[4]) else {
            throw MessageError.unknownValue(value: encodedData[3], typeDescription: "DeliveryInProgressType")
        }
        self.deliveryInProgressType = deliveryInProgressType
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[5] & 0x3) << 8) | Int(encodedData[6]))
        
        self.podMessageCounter = encodedData[7]
        self.unknownPageCode = Double(Int(encodedData[8]) | Int(encodedData[9]))
        
        self.origionalLoggedFaultEvent = encodedData[10]
        
        let minutes = ((Int(encodedData[11]) & 0x7f) << 6) + (Int(encodedData[12]) >> 2)
        self.faultEventTimeSinceActivation = TimeInterval(minutes: Double(minutes))
        
        self.data = encodedData[8...Int(self.length)]
        
    }
}
