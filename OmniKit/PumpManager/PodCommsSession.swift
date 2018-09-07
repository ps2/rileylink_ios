//
//  PodCommsSession.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/13/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit
import LoopKit

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
    case noRileyLinkAvailable
    case unfinalizedBolus
    case unfinalizedTempBasal
    case commsError(error: Error)
}

extension PodCommsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return nil
        case .crcMismatch:
            return nil
        case .unknownPacketType:
            return nil
        case .noResponse:
            return nil
        case .emptyResponse:
            return nil
        case .podAckedInsteadOfReturningResponse:
            return nil
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return nil
        case .unknownResponseType:
            return nil
        case .noRileyLinkAvailable:
            return nil
        case .unfinalizedBolus:
            return LocalizedString("Bolus in progress", comment: "Error message shown when bolus could not be completed due to exiting bolus in progress")
        case .unfinalizedTempBasal:
            return LocalizedString("Bolus in progress", comment: "Error message shown when temp basal could not be set due to exiting temp basal in progress")
        case .commsError:
            return nil
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidData:
            return nil
        case .crcMismatch:
            return nil
        case .unknownPacketType:
            return nil
        case .noResponse:
            return nil
        case .emptyResponse:
            return nil
        case .podAckedInsteadOfReturningResponse:
            return nil
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return nil
        case .unknownResponseType:
            return nil
        case .noRileyLinkAvailable:
            return nil
        case .unfinalizedBolus:
            return nil
        case .unfinalizedTempBasal:
            return LocalizedString("Unable to issue concurrent boluses", comment: "Failure reason when bolus could not be completed due to exiting bolus in progress")
        case .commsError:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidData:
            return nil
        case .crcMismatch:
            return nil
        case .unknownPacketType:
            return nil
        case .noResponse:
            return nil
        case .emptyResponse:
            return nil
        case .podAckedInsteadOfReturningResponse:
            return nil
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return nil
        case .unknownResponseType:
            return nil
        case .noRileyLinkAvailable:
            return LocalizedString("Make sure your RileyLink is nearby and powered on", comment: "Recovery suggestion")
        case .unfinalizedBolus:
            return LocalizedString("Wait for existing bolus to finish, or suspend to cancel", comment: "Recovery suggestion when bolus could not be completed due to exiting bolus in progress")
        case .unfinalizedTempBasal:
            return nil
        case .commsError:
            return nil
        }
    }
}



public protocol PodCommsSessionDelegate: class {
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState)
}

public class PodCommsSession {
    
    private var podState: PodState {
        didSet {
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
        let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .lowReservoir, audible: true, autoOffModifier: false, duration: 0, expirationType: .reservoir(volume: 20), beepType: .beepBeepBeepBeep, beepRepeat: 2)
        
        let configureAlerts1 = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig1])
        let _: StatusResponse = try send([configureAlerts1])
        podState.advanceToNextNonce()
        
        //7837 0005 0802
        let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible:true, autoOffModifier: false, duration: .minutes(55), expirationType: .time(.minutes(5)), beepType: .beeepBeeep, beepRepeat: 2)
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
        let alertConfig = ConfigureAlertsCommand.AlertConfiguration(alertType: .expirationAdvisory, audible: false, autoOffModifier: false, duration: .minutes(0), expirationType: .time(.hours(68)), beepType: .bipBip, beepRepeat: 2)
        let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig])
        let _: StatusResponse = try send([configureAlerts])
        podState.advanceToNextNonce()
    }
    
    // Throws SetBolusError
    public enum PodBolusResult {
        case success(statusResponse: StatusResponse)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }
    
    public func bolus(units: Double) -> PodBolusResult {
        
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, multiplier: 16)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        guard podState.unfinalizedBolus == nil else {
            return PodBolusResult.certainFailure(error: .unfinalizedBolus)
        }
        
        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: units, byte2: 0, unknownSection: Data(hexadecimalString: "00030d40")!)
        do {
            let statusResponse: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .certain)
            podState.advanceToNextNonce()
            return PodBolusResult.success(statusResponse: statusResponse)
        } catch let error {
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .uncertain)
            return PodBolusResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let _: StatusResponse = try send([tempBasalCommand, tempBasalExtraCommand])
        podState.advanceToNextNonce()
    }
    
    public func cancelDelivery(deliveryType: CancelDeliveryCommand.DeliveryType, beepType:ConfigureAlertsCommand.BeepType) throws {
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: deliveryType, beepType: beepType)
        
        let _: StatusResponse = try send([cancelDelivery])
        
        podState.advanceToNextNonce()
    }
    
    public func testingCommands() throws {
        //try setTempBasal(rate: 2.5, duration: .minutes(30), confidenceReminder: false, programReminderInterval: .minutes(0))
        //try cancelDelivery(deliveryType: .tempBasal, beepType: .noBeep)
        //try bolus(units: 20)
        //try cancelDelivery(deliveryType: .bolus, beepType: .bipBip)
    }
    
    public func setTime(basalSchedule: BasalSchedule, timeZone: TimeZone, date: Date) throws {
        let scheduleOffset = timeZone.scheduleOffset(forDate: date)
        try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: .minutes(0))
        self.podState.timeZone = timeZone
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
        let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible: true, autoOffModifier: false, duration: .minutes(164), expirationType: .time(podSoftExpirationTime), beepType: .beepBeepBeep, beepRepeat: 2)
        
        // 2800 1283 0602
        let podHardExpirationTime = TimeInterval(hours:79) - TimeInterval(minutes:1)
        let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .endOfService, audible: true, autoOffModifier: false, duration: .minutes(0), expirationType: .time(podHardExpirationTime), beepType: .beeeeeep, beepRepeat: 2)
        
        // 020f 0000 0202
        let alertConfig3 = ConfigureAlertsCommand.AlertConfiguration(alertType: .autoOff, audible: false, autoOffModifier: true, duration: .minutes(15), expirationType: .time(0), beepType: .bipBeepBipBeepBipBeepBipBeep, beepRepeat: 2) // Would like to change this to be less annoying, for example .bipBipBipbipBipBip

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
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: .all, beepType: .beeepBeeep)
        let _: StatusResponse = try send([cancelDelivery])
        podState.advanceToNextNonce()

        // PDM at this point makes a few get status requests, for logs and other details, presumably.
        // We don't know what to do with them, so skip for now.

        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        let _: StatusResponse = try send([deactivatePod])
    }
}

