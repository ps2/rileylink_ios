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
import os.log

public enum PodCommsError: Error {
    case noPodPaired
    case invalidData
    case noResponse
    case emptyResponse
    case podAckedInsteadOfReturningResponse
    case unexpectedPacketType(packetType: PacketType)
    case unexpectedResponse(response: MessageBlockType)
    case unknownResponseType(rawType: UInt8)
    case noRileyLinkAvailable
    case unfinalizedBolus
    case unfinalizedTempBasal
    case nonceResyncFailed
    case podSuspended
    case podFault(fault: PodInfoFaultEvent)
    case commsError(error: Error)
}

extension PodCommsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .invalidData:
            return nil
        case .noResponse:
            return LocalizedString("No response from pod", comment: "Error message shown when no response from pod was received")
        case .emptyResponse:
            return LocalizedString("Empty response from pod", comment: "Error message shown when empty response from pod was received")
        case .podAckedInsteadOfReturningResponse:
            return nil
        case .unexpectedPacketType:
            return nil
        case .unexpectedResponse:
            return LocalizedString("Unexpected response from pod", comment: "Error message shown when empty response from pod was received")
        case .unknownResponseType:
            return nil
        case .noRileyLinkAvailable:
            return LocalizedString("No RileyLink available", comment: "Error message shown when no response from pod was received")
        case .unfinalizedBolus:
            return LocalizedString("Bolus in progress", comment: "Error message shown when operation could not be completed due to existing bolus in progress")
        case .unfinalizedTempBasal:
            return LocalizedString("Temp basal in progress", comment: "Error message shown when temp basal could not be set due to existing temp basal in progress")
        case .nonceResyncFailed:
            return nil
        case .podSuspended:
            return LocalizedString("Pod is suspended", comment: "Error message action could not be performed because pod is suspended")
        case .podFault(let fault):
            let faultDescription = String(describing: fault.currentStatus)
            return String(format: LocalizedString("Pod Fault: %1$@", comment: "Format string for pod fault code"), faultDescription)
        case .commsError:
            return nil
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .invalidData:
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
            return nil
        case .nonceResyncFailed:
            return nil
        case .podSuspended:
            return nil
        case .podFault:
            return nil
        case .commsError:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .invalidData:
            return nil
        case .noResponse:
            return LocalizedString("Please bring your pod closer to the RileyLink and try again", comment: "Recovery suggestion when no response is received from pod")
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
            return LocalizedString("Make sure your RileyLink is nearby and powered on", comment: "Recovery suggestion when no RileyLink is available")
        case .unfinalizedBolus:
            return LocalizedString("Wait for existing bolus to finish, or suspend to cancel", comment: "Recovery suggestion when operation could not be completed due to existing bolus in progress")
        case .unfinalizedTempBasal:
            return LocalizedString("Wait for existing temp basal to finish, or suspend to cancel", comment: "Recovery suggestion when operation could not be completed due to existing temp basal in progress")
        case .nonceResyncFailed:
            return nil
        case .podSuspended:
            return nil
        case .podFault:
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
    
    public let log = OSLog(category: "PodCommsSession")
    
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
        transport.delegate = self
    }

    func send<T: MessageBlock>(_ messageBlocks: [MessageBlock], expectFollowOnMessage: Bool = false) throws -> T {
        
        var triesRemaining = 2  // Retries only happen for nonce resync
        
        var blocksToSend = messageBlocks
        
        if blocksToSend.contains(where: { $0 as? NonceResyncableMessageBlock != nil }) {
            podState.advanceToNextNonce()
        }
        
        let messageNumber = transport.messageNumber
        
        while (triesRemaining > 0) {
            triesRemaining -= 1
            
            let message = Message(address: podState.address, messageBlocks: blocksToSend, sequenceNum: messageNumber, expectFollowOnMessage: expectFollowOnMessage)
            
            let response = try transport.sendMessage(message)
            
            // Simulate fault
            //let response = try Message(encodedData: Data(hexadecimalString: "1f019ee204180216020d0000a902012d14008d03ff008d0000185e08030d81cd")!)
            
            if let responseMessageBlock = response.messageBlocks[0] as? T {
                log.info("POD Response: %@", String(describing: responseMessageBlock))
                return responseMessageBlock
            } else {
                let responseType = response.messageBlocks[0].blockType
                
                if responseType == .errorResponse,
                    let errorResponse = response.messageBlocks[0] as? ErrorResponse,
                    errorResponse.errorReponseType == .badNonce
                {
                    let sentNonce = podState.currentNonce
                    self.podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: sentNonce, messageSequenceNum: message.sequenceNum)
                    log.info("resyncNonce(syncWord: %02X, sentNonce: %04X, messageSequenceNum: %d) -> %04X", errorResponse.nonceSearchKey, sentNonce, message.sequenceNum, podState.currentNonce)
                    
                    blocksToSend = blocksToSend.map({ (block) -> MessageBlock in
                        if var resyncableBlock = block as? NonceResyncableMessageBlock {
                            resyncableBlock.nonce = podState.currentNonce
                            return resyncableBlock
                        } else {
                            return block
                        }
                    })
                } else if let fault = response.fault {
                    self.podState.fault = fault
                    log.error("Pod Fault: %@", String(describing: fault))
                    let now = Date()
                    if fault.deliveryStatus == .suspended {
                        podState.unfinalizedTempBasal?.cancel(at: now)
                        podState.unfinalizedBolus?.cancel(at: now, withRemaining: fault.insulinNotDelivered)
                    }

                    throw PodCommsError.podFault(fault: fault)
                }
                else {
                    log.error("Unexpected response: %@", String(describing: response.messageBlocks[0]))
                    throw PodCommsError.unexpectedResponse(response: responseType)
                }
            }
        }
        throw PodCommsError.nonceResyncFailed
    }

    // Returns time at which prime is expected to finish.
    public func prime() throws -> Date {
        //4c00 00c8 0102
        
        // Skip following alerts if we've already done them before
        if podState.setupProgress != .startingPrime {
            
            // Uncomment the following to set Tab5[$16] to 0 during pairing, which should disable $6x faults.
            //let _: StatusResponse = try send([FaultConfigCommand(nonce: podState.currentNonce, tab5Sub16: 0, tab5Sub17: 0)])
    
            let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .lowReservoir, audible: true, autoOffModifier: false, duration: 0, expirationType: .reservoir(volume: 20), beepRepeat: .every1MinuteFor15Minutes, beepType: .beepBeepBeepBeep)
            
            let configureAlerts1 = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig1])
            let _: StatusResponse = try send([configureAlerts1])
            
            //7837 0005 0802
            let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible:true, autoOffModifier: false, duration: .minutes(55), expirationType: .time(.minutes(5)), beepRepeat: .every1MinuteFor15Minutes, beepType: .beeepBeeep)
            let configureAlerts2 = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig2])
            let _: StatusResponse = try send([configureAlerts2])
        } else {
            // We started prime, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .priming || status.podProgressStatus == .readyForBasalSchedule {
                podState.setupProgress = .priming
                return podState.primeFinishTime!
            }
        }

        // Mark 2.6U delivery for prime
        
        let primeFinishTime = Date() + .seconds(55)
        podState.primeFinishTime = primeFinishTime
        podState.setupProgress = .startingPrime

        let primeUnits = 2.6
        let timeBetweenPulses = TimeInterval(seconds: 1)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: primeUnits, timeBetweenPulses: timeBetweenPulses)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: primeUnits, timeBetweenPulses: timeBetweenPulses)
        let status: StatusResponse = try send([scheduleCommand, bolusExtraCommand])
        podState.updateFromStatusResponse(status)
        podState.setupProgress = .priming
        return primeFinishTime
    }
    
    public func programInitialBasalSchedule(_ basalSchedule: BasalSchedule, scheduleOffset: TimeInterval) throws {
        // 3800 0ff0 0302
        if podState.setupProgress != .settingInitialBasalSchedule {
            let alertConfig = ConfigureAlertsCommand.AlertConfiguration(alertType: .expirationAdvisory, audible: false, autoOffModifier: false, duration: .minutes(0), expirationType: .time(.hours(68)), beepRepeat: .every1MinuteFor15Minutes, beepType: .bipBip)
            let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig])
            let status: StatusResponse = try send([configureAlerts])
            podState.updateFromStatusResponse(status)
        } else {
            // We started basal schedule programming, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .readyForCannulaInsertion {
                podState.setupProgress = .initialBasalScheduleSet
                return
            }
        }
        
        podState.setupProgress = .settingInitialBasalSchedule
        // Set basal schedule
        let status2 = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: .minutes(0))
        podState.updateFromStatusResponse(status2)
        podState.setupProgress = .initialBasalScheduleSet
    }
    
    public func insertCannula() throws -> Date {
        // Configure Alerts
        // 79a4 10df 0502
        // Pod expires 1 minute short of 3 days
        if podState.setupProgress != .startingInsertCannula {
            let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible: true, autoOffModifier: false, duration: .minutes(164), expirationType: .time(podSoftExpirationTime), beepRepeat: .every1MinuteFor15Minutes, beepType: .beepBeepBeep)
            
            // 2800 1283 0602
            let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .endOfService, audible: true, autoOffModifier: false, duration: .minutes(0), expirationType: .time(podHardExpirationTime), beepRepeat: .every1MinuteFor15Minutes, beepType: .beeeeeep)
            
            // 020f 0000 0202
            let alertConfig3 = ConfigureAlertsCommand.AlertConfiguration(alertType: .autoOff, audible: false, autoOffModifier: true, duration: .minutes(15), expirationType: .time(0), beepRepeat: .every1MinuteFor15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep) // Would like to change this to be less annoying, for example .bipBipBipbipBipBip
            
            let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations:[alertConfig1, alertConfig2, alertConfig3])
            
            let status: StatusResponse = try send([configureAlerts])
            podState.updateFromStatusResponse(status)
        } else {
            // We started cannula insertion, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .cannulaInserting || status.podProgressStatus == .aboveFiftyUnits {
                podState.setupProgress = .completed
                return Date() + .seconds(10)
            }
        }
        
        // Insert Cannula
        // 1a0e7e30bf16020065010050000a000a
        let insertionBolusAmount = 0.5
        let timeBetweenPulses = TimeInterval(seconds: 1)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: insertionBolusAmount, timeBetweenPulses: timeBetweenPulses)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        // 17 0d 00 0064 0001 86a0000000000000
        podState.setupProgress = .startingInsertCannula
        let bolusExtraCommand = BolusExtraCommand(units: insertionBolusAmount, timeBetweenPulses: timeBetweenPulses)
        let status2: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
        podState.updateFromStatusResponse(status2)
        
        let cannulaInsertionFinishTime = Date() + .seconds(10)
        podState.setupProgress = .completed
        return cannulaInsertionFinishTime
    }

    
    // Throws SetBolusError
    public enum DeliveryCommandResult {
        case success(statusResponse: StatusResponse)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }
    
    public func bolus(units: Double) -> DeliveryCommandResult {
        
        let timeBetweenPulses = TimeInterval(seconds: 2)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, timeBetweenPulses: timeBetweenPulses)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        guard podState.unfinalizedBolus == nil else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }
        
        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: units)
        do {
            let statusResponse: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .certain)
            return DeliveryCommandResult.success(statusResponse: statusResponse)
        } catch let error {
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .uncertain)
            return DeliveryCommandResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) -> DeliveryCommandResult {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)

        guard podState.unfinalizedBolus?.finished != false else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }

        do {
            let status: StatusResponse = try send([tempBasalCommand, tempBasalExtraCommand])
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .certain)
            podState.updateFromStatusResponse(status)
            return DeliveryCommandResult.success(statusResponse: status)
        } catch let error {
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .uncertain)
            return DeliveryCommandResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }
    
    public func cancelDelivery(deliveryType: CancelDeliveryCommand.DeliveryType, beepType:ConfigureAlertsCommand.BeepType) throws -> StatusResponse {
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: deliveryType, beepType: beepType)
        
        let status: StatusResponse = try send([cancelDelivery])
        
        let now = Date()
        
        if let unfinalizedTempBasal = podState.unfinalizedTempBasal,
            deliveryType.contains(.tempBasal),
            unfinalizedTempBasal.finishTime.compare(now) == .orderedDescending
        {
            podState.unfinalizedTempBasal?.cancel(at: now)
            log.info("Interrupted temp basal: %@", String(describing: unfinalizedTempBasal))
        }
        
        if let unfinalizedBolus = podState.unfinalizedBolus,
            deliveryType.contains(.bolus),
            unfinalizedBolus.finishTime.compare(now) == .orderedDescending
        {
            podState.unfinalizedBolus?.cancel(at: now, withRemaining: status.insulinNotDelivered)
            log.info("Interrupted bolus: %@", String(describing: unfinalizedBolus))
        }
        
        podState.updateFromStatusResponse(status)

        return status
    }

    public func testingCommands() throws {
//        let _ = try cancelDelivery(deliveryType: .all, beepType: .noBeep)
//        let response: StatusResponse = try send([FaultConfigCommand(nonce: podState.currentNonce, tab5Sub16: 1, tab5Sub17: 0)])
//        print(response)
    }
    
    public func setTime(timeZone: TimeZone, basalSchedule: BasalSchedule, date: Date) throws -> StatusResponse {
        let _ = try cancelDelivery(deliveryType: .all, beepType: .noBeep)
        let scheduleOffset = timeZone.scheduleOffset(forDate: date)
        let status = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: .minutes(0))
        return status
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws -> StatusResponse {

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let status: StatusResponse = try send([basalScheduleCommand, basalExtraCommand])
        return status
    }
    
    public func resumeBasal(schedule: BasalSchedule, scheduleOffset: TimeInterval, confidenceReminder: Bool = false, programReminderInterval: TimeInterval = 0) throws -> StatusResponse {
        
        let status = try setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        podState.updateFromStatusResponse(status)
        
        return status
    }
    
    public func getStatus() throws -> StatusResponse {
        let response: StatusResponse = try send([GetStatusCommand()])
        podState.updateFromStatusResponse(response)
        return response
    }
    
    public func deactivatePod() throws {
        
        if podState.fault == nil && !podState.suspended {
            let _ = try cancelDelivery(deliveryType: .all, beepType: .beeepBeeep)
        }
        
        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        
        if podState.fault != nil {
            let _: PodInfoResponse = try send([deactivatePod])
        } else {
            let _: StatusResponse = try send([deactivatePod])
        }
    }
    
    public func acknowledgeAlarms(alarms: PodAlarmState) throws -> StatusResponse {
        
        let cmd = AcknowledgeAlertCommand(nonce: podState.currentNonce, alarms: alarms)
        let status: StatusResponse = try send([cmd])

        return status
    }

    
    func storeFinalizedDoses(_ storageHandler: ([UnfinalizedDose]) -> Bool) {
        if storageHandler(podState.finalizedDoses) {
            log.info("Finalized %@", String(describing: podState.finalizedDoses))
            self.podState.finalizedDoses.removeAll()
        }
    }
}

extension PodCommsSession: MessageTransportDelegate {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: MessageTransportState) {
        podState.messageTransportState = state
    }
}



