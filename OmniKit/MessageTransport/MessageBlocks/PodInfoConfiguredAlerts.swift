//
//  PodInfoConfiguredAlerts.swift
//  OmniKit
//
//  Created by Eelke Jager on 16/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoConfiguredAlerts : PodInfo {

    public var podInfoType : PodInfoResponseSubType = .configuredAlerts
    public let word_278    : Data
    public let alertsActivations : [AlertActivation]

    public let data       : Data

    public struct AlertActivation {
        let beepType: BeepType
        let unitsLeft: Double
        let timeFromPodStart: UInt8
        
        public init(beepType: BeepType, timeFromPodStart: UInt8, unitsLeft: Double) {
            self.beepType = beepType
            self.timeFromPodStart = timeFromPodStart
            self.unitsLeft = unitsLeft
        }
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < Int(11) {
            throw MessageBlockError.notEnoughData
        }
        self.podInfoType = PodInfoResponseSubType.init(rawValue: encodedData[0])!
        self.word_278 = encodedData[1...2]
        
        let numAlertTypes = 8
        let beepType = BeepType.self
        
        var activations = [AlertActivation]()

        for alarmType in (0..<numAlertTypes) {
            let beepType = beepType.init(rawValue: UInt8(alarmType))
            let timeFromPodStart = encodedData[(3 + alarmType * 2)] // Double(encodedData[(5 + alarmType)] & 0x3f)
            let unitsLeft = Double(encodedData[(4 + alarmType * 2)]) * Pod.pulseSize
            activations.append(AlertActivation(beepType: beepType!, timeFromPodStart: timeFromPodStart, unitsLeft: unitsLeft))
        }
        alertsActivations = activations
        self.data         = encodedData
    }
}

