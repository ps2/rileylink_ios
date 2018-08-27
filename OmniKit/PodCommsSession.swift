//
//  PodCommsSession.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit

public enum PodCommsError: Error {
    case invalidData
    case crcMismatch
    case unknownPacketType(rawType: UInt8)
    case noResponse
    case emptyResponse
    case podAckedInsteadOfReturningResponse
    case unexpectedPacketType(packetType: PacketType)
    case unexpectedResponse(response: MessageBlockType)
    case unknownResponseType(rawType: UInt8)
    case noPairedPod
    case noRileyLinkAvailable
}


public protocol PodCommsSessionDelegate: class {
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState)
}

public class PodCommsSession {
    
    private var podState: PodState {
        didSet {
            print("PodCommsSession.didChange podState: \(String(describing: podState))")
            delegate.podCommsSession(self, didChange: podState)
        }
    }
    
    private unowned let delegate: PodCommsSessionDelegate
    private let transport: MessageTransport

    init(podState: PodState, transport: MessageTransport, delegate: PodCommsSessionDelegate) {
        self.podState = podState
        self.transport = transport
        self.delegate = delegate
    }


    func send<T: MessageBlock>(_ messageBlocks: [MessageBlock]) throws -> T {
        
        let response = try transport.send(messageBlocks)
        
        guard let responseMessageBlock = response.messageBlocks[0] as? T else {
            let responseType = response.messageBlocks[0].blockType
            
            if responseType == .errorResponse,
                let errorResponse = response.messageBlocks[0] as? ErrorResponse,
                errorResponse.errorReponseType == .badNonce
            {
                print("Pod returned bad nonce error.  Resyncing...")
                self.podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: podState.currentNonce, messageSequenceNum: response.sequenceNum)
            }
            print("Unexpected response: \(responseType), \(response.messageBlocks[0])")
            throw PodCommsError.unexpectedResponse(response: responseType)
        }
        
        print("POD Response: \(responseMessageBlock)")
        return responseMessageBlock
    }

    public func configurePod() throws {
        //4c00 00c8 0102
        let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .lowReservoir, audible: true, autoOffModifier: false, duration: 0, expirationType: .reservoir(volume: 20), beepType: 0x0102)
        
        let configureAlerts1 = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig1])
        let _: StatusResponse = try send([configureAlerts1])
        podState.advanceToNextNonce()
        
        //7837 0005 0802
        let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible:true, autoOffModifier: false, duration: .minutes(55), expirationType: .time(.minutes(5)), beepType: 0x0802)
        let configureAlerts2 = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig2])
        let _: StatusResponse = try send([configureAlerts2])
        podState.advanceToNextNonce()

        // Mark 2.6U delivery for prime
        
        // 1a0e bed2e16b 02 010a 01 01a0 0034 0034 170d 00 0208 000186a0
        let primeUnits = 2.6
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: primeUnits, multiplier: 8)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: primeUnits, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let _: StatusResponse = try send([scheduleCommand, bolusExtraCommand])
        podState.advanceToNextNonce()
    }
    
    public func finishPrime() throws {
        // 3800 0ff0 0302
        let alertConfig = ConfigureAlertsCommand.AlertConfiguration(alertType: .expirationAdvisory, audible: false, autoOffModifier: false, duration: .minutes(0), expirationType: .time(.hours(68)), beepType: 0x0302)
        let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig])
        let _: StatusResponse = try send([configureAlerts])
        podState.advanceToNextNonce()
    }
    
    public func bolus(units: Double) throws {
        
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, multiplier: 16)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: units, byte2: 0, unknownSection: Data(hexadecimalString: "00030d40")!)
        let _: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let _: StatusResponse = try send([tempBasalCommand, tempBasalExtraCommand])
        podState.advanceToNextNonce()
    }
    
    public func cancelTempBasal() throws {
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: .tempBasal)
        
        let _: StatusResponse = try send([cancelDelivery])
        
        podState.advanceToNextNonce()
    }
    
    public func testingCommands() throws {
        try setTempBasal(rate: 1.0, duration: .minutes(30), confidenceReminder: false, programReminderInterval: .minutes(0))
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws {

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let _: StatusResponse = try send([basalScheduleCommand, basalExtraCommand])
        podState.advanceToNextNonce()
    }
    
    public func insertCannula(basalSchedule: BasalSchedule, scheduleOffset: TimeInterval) throws {
        
        // Set basal schedule
        try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: .minutes(0))
        
        // Configure Alerts
        // 79a4 10df 0502
        // Pod expires 1 minute short of 3 days
        let podSoftExpirationTime = TimeInterval(hours:72) - TimeInterval(minutes:1)
        let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible: true, autoOffModifier: false, duration: .minutes(164), expirationType: .time(podSoftExpirationTime), beepType: 0x0502)
        
        // 2800 1283 0602
        let podHardExpirationTime = TimeInterval(hours:79) - TimeInterval(minutes:1)
        let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .endOfService, audible: true, autoOffModifier: false, duration: .minutes(0), expirationType: .time(podHardExpirationTime), beepType: 0x0602)
        
        // 020f 0000 0202
        let alertConfig3 = ConfigureAlertsCommand.AlertConfiguration(alertType: .autoOff, audible: false, autoOffModifier: true, duration: .minutes(15), expirationType: .time(0), beepType: 0x0202)

        let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig1, alertConfig2, alertConfig3])

        do {
            let _: StatusResponse = try send([configureAlerts])
        } catch PodCommsError.podAckedInsteadOfReturningResponse {
            print("pod acked?")
        }
        
        podState.advanceToNextNonce()

        // Insert Cannula
        // 1a0e7e30bf16020065010050000a000a
        let insertionBolusAmount = 0.5
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: insertionBolusAmount, multiplier: 8)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)

        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: insertionBolusAmount, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let _: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
        podState.advanceToNextNonce()
    }
    
    public func getStatus() throws -> StatusResponse {
        
        let response: StatusResponse = try send([GetStatusCommand()])
        return response
    }
    
    public func changePod() throws {
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: .all, cancelType: .suspend)
        let _: StatusResponse = try send([cancelDelivery])
        podState.advanceToNextNonce()

        // PDM at this point makes a few get status requests, for logs and other details, presumably.
        // We don't know what to do with them, so skip for now.

        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        let _: StatusResponse = try send([deactivatePod])
    }
}

