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
            return LocalizedString("Wait for existing bolus to finish, or cancel bolus", comment: "Recovery suggestion when operation could not be completed due to existing bolus in progress")
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
    private var transport: MessageTransport

    init(podState: PodState, transport: MessageTransport, delegate: PodCommsSessionDelegate) {
        self.podState = podState
        self.transport = transport
        self.delegate = delegate
        self.transport.delegate = self
    }

    /// Performs a message exchange, handling nonce resync, pod faults
    ///
    /// - Parameters:
    ///   - messageBlocks: The message blocks to send
    ///   - expectFollowOnMessage: If true, the pod will expect another message within 4 minutes, or will alarm with an 0x33 (51) fault.
    /// - Returns: The received message response
    /// - Throws:
    ///     - PodCommsError.nonceResyncFailed
    ///     - PodCommsError.noResponse
    ///     - MessageError.invalidCrc
    ///     - RileyLinkDeviceError
    func send<T: MessageBlock>(_ messageBlocks: [MessageBlock], expectFollowOnMessage: Bool = false) throws -> T {
        
        var triesRemaining = 2  // Retries only happen for nonce resync
        
        var blocksToSend = messageBlocks
        
        if blocksToSend.contains(where: { $0 as? NonceResyncableMessageBlock != nil }) {
            podState.advanceToNextNonce()
        }
        
        let messageNumber = transport.messageNumber

        var sentNonce: UInt32?


        while (triesRemaining > 0) {
            triesRemaining -= 1

            if let nonceBlock = messageBlocks[0] as? NonceResyncableMessageBlock {
                sentNonce = nonceBlock.nonce
            }

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
                    let sentNonce = sentNonce,
                    let errorResponse = response.messageBlocks[0] as? ErrorResponse,
                    errorResponse.errorReponseType == .badNonce
                {
                    podState.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: sentNonce, messageSequenceNum: message.sequenceNum)
                    log.info("resyncNonce(syncWord: %02X, sentNonce: %04X, messageSequenceNum: %d) -> %04X", errorResponse.nonceSearchKey, sentNonce, message.sequenceNum, podState.currentNonce)
                    
                    blocksToSend = blocksToSend.map({ (block) -> MessageBlock in
                        if var resyncableBlock = block as? NonceResyncableMessageBlock {
                            resyncableBlock.nonce = podState.currentNonce
                            return resyncableBlock
                        } else {
                            return block
                        }
                    })
                    podState.advanceToNextNonce()
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
    public func prime() throws -> TimeInterval {
        //4c00 00c8 0102

        let primeDuration = TimeInterval(seconds: 55)
        
        // Skip following alerts if we've already done them before
        if podState.setupProgress != .startingPrime {
            
            // The following will set Tab5[$16] to 0 during pairing, which disables $6x faults.
            let _: StatusResponse = try send([FaultConfigCommand(nonce: podState.currentNonce, tab5Sub16: 0, tab5Sub17: 0)])

            // Uncomment to get an audible pod alert for low reservoir
//            let lowReservoirAlarm = PodAlert.lowReservoirAlarm(20) // Alarm at 20 units remaining
//            let _ = try configureAlerts([lowReservoirAlarm])

            let finishSetupReminder = PodAlert.finishSetupReminder
            let _ = try configureAlerts([finishSetupReminder])
        } else {
            // We started prime, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .priming || status.podProgressStatus == .readyForBasalSchedule {
                podState.setupProgress = .priming
                return podState.primeFinishTime?.timeIntervalSinceNow ?? primeDuration
            }
        }

        // Mark 2.6U delivery for prime
        
        let primeFinishTime = Date() + primeDuration
        podState.primeFinishTime = primeFinishTime
        podState.setupProgress = .startingPrime

        let timeBetweenPulses = TimeInterval(seconds: 1)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: Pod.primeUnits, timeBetweenPulses: timeBetweenPulses)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: Pod.primeUnits, timeBetweenPulses: timeBetweenPulses)
        let status: StatusResponse = try send([scheduleCommand, bolusExtraCommand])
        podState.updateFromStatusResponse(status)
        podState.setupProgress = .priming
        return primeFinishTime.timeIntervalSinceNow
    }
    
    public func programInitialBasalSchedule(_ basalSchedule: BasalSchedule, scheduleOffset: TimeInterval) throws {
        if podState.setupProgress == .settingInitialBasalSchedule {
            // We started basal schedule programming, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .readyForCannulaInsertion {
                podState.setupProgress = .initialBasalScheduleSet
                return
            }
        } else {
            // Uncomment the following to get an audible expiration notice before the expiration advisory alert
//            let timeUntilExpirationAlert = (podState.activatedAt + Pod.serviceDuration - Pod.endOfServiceImminentWindow - Pod.expirationAdvisoryWindow - Pod.expirationAlertWindow).timeIntervalSinceNow
//            let expirationAlert = PodAlert.expirationAlert(timeUntilExpirationAlert)
//            let _ = try configureAlerts([expirationAlert])
        }
        
        podState.setupProgress = .settingInitialBasalSchedule
        // Set basal schedule
        let _ = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, acknowledgementBeep: false, completionBeep: false, programReminderInterval: .minutes(0))
        podState.setupProgress = .initialBasalScheduleSet
        podState.finalizedDoses.append(UnfinalizedDose(resumeStartTime: Date(), scheduledCertainty: .certain))
    }

    private func configureAlerts(_ alerts: [PodAlert]) throws -> StatusResponse {
        let configurations = alerts.map { $0.configuration }
        let configureAlerts = ConfigureAlertsCommand(nonce: podState.currentNonce, configurations: configurations)
        let status: StatusResponse = try send([configureAlerts])
        for alert in alerts {
            podState.registerConfiguredAlert(slot: alert.configuration.slot, alert: alert)
        }
        podState.updateFromStatusResponse(status)
        return status
    }
    
    public func insertCannula() throws -> TimeInterval {
        let insertionWait: TimeInterval = .seconds(10)

        guard let activatedAt = podState.activatedAt else {
            throw PodCommsError.noPodPaired
        }

        if podState.setupProgress == .startingInsertCannula || podState.setupProgress == .cannulaInserting {
            // We started cannula insertion, but didn't get confirmation somehow, so check status
            let status: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(status)
            if status.podProgressStatus == .cannulaInserting {
                podState.setupProgress = .cannulaInserting
                return insertionWait// Not sure when it started, wait full time to be sure
            }
            if status.podProgressStatus.readyForDelivery {
                podState.setupProgress = .completed
                return TimeInterval(0) // Already done; no need to wait
            }
        } else {
            // Configure Alerts
            let endOfServiceTime = activatedAt + Pod.serviceDuration
            let timeUntilExpirationAdvisory = (endOfServiceTime - Pod.endOfServiceImminentWindow - Pod.expirationAdvisoryWindow).timeIntervalSinceNow
            let expirationAdvisoryAlarm = PodAlert.expirationAdvisoryAlarm(alarmTime: timeUntilExpirationAdvisory, duration: Pod.expirationAdvisoryWindow)
            let shutdownImminentAlarm = PodAlert.shutdownImminentAlarm((endOfServiceTime - Pod.endOfServiceImminentWindow).timeIntervalSinceNow)
            let autoOffAlarm = PodAlert.autoOffAlarm(active: false, countdownDuration: 0) // Turn Auto-off feature off
            let _ = try configureAlerts([expirationAdvisoryAlarm, shutdownImminentAlarm, autoOffAlarm])
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
        
        podState.setupProgress = .cannulaInserting
        return insertionWait
    }

    public func checkInsertionCompleted() throws {
        if podState.setupProgress == .cannulaInserting {
            let response: StatusResponse = try send([GetStatusCommand()])
            podState.updateFromStatusResponse(response)
            if response.podProgressStatus.readyForDelivery {
                podState.setupProgress = .completed
            }
        }
    }
    
    // Throws SetBolusError
    public enum DeliveryCommandResult {
        case success(statusResponse: StatusResponse)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }

    public enum CancelDeliveryResult {
        case success(statusResponse: StatusResponse, canceledBolus: UnfinalizedDose?)
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
            // Between bluetooth and the radio and firmware, about 1.2s on average passes before we start tracking
            let commsOffset = TimeInterval(seconds: -1.5)
            let statusResponse: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date().addingTimeInterval(commsOffset), scheduledCertainty: .certain)
            return DeliveryCommandResult.success(statusResponse: statusResponse)
        } catch PodCommsError.nonceResyncFailed {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch let error {
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .uncertain)
            return DeliveryCommandResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, acknowledgementBeep: Bool, completionBeep: Bool, programReminderInterval: TimeInterval) -> DeliveryCommandResult {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        guard podState.unfinalizedBolus?.finished != false else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }

        do {
            let status: StatusResponse = try send([tempBasalCommand, tempBasalExtraCommand])
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .certain)
            podState.updateFromStatusResponse(status)
            return DeliveryCommandResult.success(statusResponse: status)
        } catch PodCommsError.nonceResyncFailed {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch let error {
            podState.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: rate, startTime: Date(), duration: duration, scheduledCertainty: .uncertain)
            return DeliveryCommandResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }
    
    public func cancelDelivery(deliveryType: CancelDeliveryCommand.DeliveryType, beepType: BeepType) -> CancelDeliveryResult {
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: deliveryType, beepType: beepType)

        do {
            let status: StatusResponse = try send([cancelDelivery])
            let now = Date()
            if deliveryType.contains(.basal) {
                podState.unfinalizedSuspend = UnfinalizedDose(suspendStartTime: now, scheduledCertainty: .certain)
            }

            if let unfinalizedTempBasal = podState.unfinalizedTempBasal,
                let finishTime = unfinalizedTempBasal.finishTime,
                deliveryType.contains(.tempBasal),
                finishTime.compare(now) == .orderedDescending
            {
                podState.unfinalizedTempBasal?.cancel(at: now)
                log.info("Interrupted temp basal: %@", String(describing: unfinalizedTempBasal))
            }

            var canceledBolus: UnfinalizedDose? = nil

            if let unfinalizedBolus = podState.unfinalizedBolus,
                let finishTime = unfinalizedBolus.finishTime,
                deliveryType.contains(.bolus),
                finishTime.compare(now) == .orderedDescending
            {
                podState.unfinalizedBolus?.cancel(at: now, withRemaining: status.insulinNotDelivered)
                canceledBolus = podState.unfinalizedBolus
                log.info("Interrupted bolus: %@", String(describing: canceledBolus))
            }

            podState.updateFromStatusResponse(status)

            return CancelDeliveryResult.success(statusResponse: status, canceledBolus: canceledBolus)

        } catch PodCommsError.nonceResyncFailed {
            return CancelDeliveryResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch let error {
            podState.unfinalizedSuspend = UnfinalizedDose(suspendStartTime: Date(), scheduledCertainty: .uncertain)
            return CancelDeliveryResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }

    public func testingCommands() throws {
        let _ = try getStatus()
    }
    
    public func setTime(timeZone: TimeZone, basalSchedule: BasalSchedule, date: Date) throws -> StatusResponse {
        let result = cancelDelivery(deliveryType: .all, beepType: .noBeep)
        switch result {
        case .certainFailure(let error):
            throw error
        case .uncertainFailure(let error):
            throw error
        case .success:
            let scheduleOffset = timeZone.scheduleOffset(forDate: date)
            let status = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, acknowledgementBeep: false, completionBeep: false, programReminderInterval: .minutes(0))
            return status
        }
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool, completionBeep: Bool, programReminderInterval: TimeInterval) throws -> StatusResponse {

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        do {
            let status: StatusResponse = try send([basalScheduleCommand, basalExtraCommand])
            podState.unfinalizedResume = UnfinalizedDose(resumeStartTime: Date(), scheduledCertainty: .certain)
            podState.updateFromStatusResponse(status)
            return status
        } catch PodCommsError.nonceResyncFailed {
            throw PodCommsError.nonceResyncFailed
        } catch let error {
            podState.unfinalizedResume = UnfinalizedDose(resumeStartTime: Date(), scheduledCertainty: .uncertain)
            throw error
        }
    }
    
    public func resumeBasal(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) throws -> StatusResponse {
        
        let status = try setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: programReminderInterval)

        return status
    }
    
    public func getStatus() throws -> StatusResponse {
        let response: StatusResponse = try send([GetStatusCommand()])
        podState.updateFromStatusResponse(response)
        return response
    }
    
    public func deactivatePod() throws {

        do {
            if podState.fault == nil && !podState.suspended {
                let result = cancelDelivery(deliveryType: .all, beepType: .beeepBeeep)
                switch result {
                case .certainFailure(let error):
                    throw error
                case .uncertainFailure(let error):
                    throw error
                default:
                    break
                }
            }
        } catch let error as PodCommsError {
            if case .podFault = error {
                // Ignore fault response during deactivation; it has been stored to pod state at this point.
            } else {
                throw error
            }
        }
        
        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        
        if podState.fault != nil {
            let _: PodInfoResponse = try send([deactivatePod])
        } else {
            let _: StatusResponse = try send([deactivatePod])
        }
    }
    
    public func acknowledgeAlerts(alerts: AlertSet) throws -> [AlertSlot: PodAlert] {
        let cmd = AcknowledgeAlertCommand(nonce: podState.currentNonce, alerts: alerts)
        let status: StatusResponse = try send([cmd])
        podState.updateFromStatusResponse(status)
        return podState.activeAlerts
    }

    func dosesForStorage(_ storageHandler: ([UnfinalizedDose]) -> Bool) {
        let dosesToStore = podState.dosesToStore

        if storageHandler(dosesToStore) {
            log.info("Stored %@", String(describing: dosesToStore))
            self.podState.finalizedDoses.removeAll()
        }
    }
}

extension PodCommsSession: MessageTransportDelegate {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: MessageTransportState) {
        podState.messageTransportState = state
    }
}



