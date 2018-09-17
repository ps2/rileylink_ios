//
//  StatusResponseConfiguredAlarms.swift
//  OmniKit
//
//  Created by Eelke Jager on 16/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusResponseConfiguredAlerts : StatusMessageBlock {

    public let blockType  : MessageBlockType = .statusError
    public let length     : UInt8
    public var statusType : StatusMessageBlockType = .configuredAlerts
    public let word_278   : Data
    public let alertsActivations : [AlertActivation]

    public let data       : Data

    public struct AlertActivation {
        let beepType: ConfigureAlertsCommand.BeepType
        let pulsesLeft: Double
        let timeFromPodStart: UInt8
        
        public init(beepType: ConfigureAlertsCommand.BeepType, timeFromPodStart: UInt8, pulsesLeft: Double) {
            self.beepType = beepType
            self.timeFromPodStart = timeFromPodStart
            self.pulsesLeft = pulsesLeft
        }
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < Int(13) {
            throw MessageBlockError.notEnoughData
        }
        
        self.length                       = encodedData[1]
        self.statusType                   = StatusMessageBlockType(rawValue: encodedData[2])!
        self.word_278                     = encodedData[3...4]
        
        let numAlertTypes = 8
        let beepType = ConfigureAlertsCommand.BeepType.self
        
        var activations = [AlertActivation]()

        for alarmType in (0..<numAlertTypes) {
            let beepType = beepType.init(rawValue: UInt8(alarmType))
            let timeFromPodStart = encodedData[(5 + alarmType * 2)] // Double(encodedData[(5 + alarmType)] & 0x3f)
            let pulsesLeft = Double(encodedData[(6 + alarmType * 2)]) * podPulseSize
            activations.append(AlertActivation(beepType: beepType!, timeFromPodStart: timeFromPodStart, pulsesLeft: pulsesLeft))
        }
        alertsActivations = activations
        self.data         = encodedData
    }
}

