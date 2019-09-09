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
    private let useCancelNoneForStatus: Bool = false             // whether to always use a cancel none to get status
    private let podLowReservoirLevel: Double = 20                // default pod low reservoir alert value
    
    public let log = OSLog(category: "PodCommsSession")
    
    private var podState: PodState {
        didSet {
            assertOnSessionQueue()
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

    private func handlePodFault(fault: PodInfoFaultEvent) {
        self.podState.fault = fault
        log.error("Pod Fault: %@", String(describing: fault))
        if fault.deliveryStatus == .suspended {
            let now = Date()
            podState.unfinalizedTempBasal?.cancel(at: now)
            podState.unfinalizedBolus?.cancel(at: now, withRemaining: fault.insulinNotDelivered)
        }
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
            //let podInfoResponse = try PodInfoResponse(encodedData: Data(hexadecimalString: "0216020d0000000000ab6a038403ff03860000285708030d0000")!)
            //let response = Message(address: podState.address, messageBlocks: [podInfoResponse], sequenceNum: message.sequenceNum)

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
                    handlePodFault(fault: fault)
                    throw PodCommsError.podFault(fault: fault)
                } else {
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
        }
        
        podState.setupProgress = .settingInitialBasalSchedule
        // Set basal schedule
        let _ = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset)
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

    // emits the specified beep type and sets the completion beep flags based on the specified confirmationBeep value
    public func beepConfig(beepConfigType: BeepConfigType, basalCompletionBeep: Bool, tempBasalCompletionBeep: Bool, bolusCompletionBeep: Bool) throws {
        guard self.podState.fault == nil else {
            return // skip if already faulted to avoid a Beep Config Command error response
        }
        
        let beepConfigCommand = BeepConfigCommand(beepConfigType: beepConfigType, basalCompletionBeep: basalCompletionBeep, tempBasalCompletionBeep: tempBasalCompletionBeep, bolusCompletionBeep: bolusCompletionBeep)
        let statusResponse: StatusResponse = try send([beepConfigCommand])
        podState.updateFromStatusResponse(statusResponse)
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
            // Configure all the non-optional Pod Alarms
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
        case success(statusResponse: StatusResponse, canceledDose: UnfinalizedDose?)
        case certainFailure(error: PodCommsError)
        case uncertainFailure(error: PodCommsError)
    }

    
    public func bolus(units: Double, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) -> DeliveryCommandResult {
        
        let timeBetweenPulses = TimeInterval(seconds: 2)
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, timeBetweenPulses: timeBetweenPulses)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, deliverySchedule: bolusSchedule)
        
        guard podState.unfinalizedBolus == nil else {
            return DeliveryCommandResult.certainFailure(error: .unfinalizedBolus)
        }
        
        // Between bluetooth and the radio and firmware, about 1.2s on average passes before we start tracking
        let commsOffset = TimeInterval(seconds: -1.5)
        
        let bolusExtraCommand = BolusExtraCommand(units: units, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep)
        do {
            let statusResponse: StatusResponse = try send([bolusScheduleCommand, bolusExtraCommand])
            podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date().addingTimeInterval(commsOffset), scheduledCertainty: .certain)
            return DeliveryCommandResult.success(statusResponse: statusResponse)
        } catch PodCommsError.nonceResyncFailed {
            return DeliveryCommandResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch let error {
            self.log.debug("Uncertain result bolusing")
            // Attempt to verify bolus
            let podCommsError = error as? PodCommsError ?? PodCommsError.commsError(error: error)
            guard let status = try? getStatus() else {
                self.log.debug("Status check failed; could not resolve bolus uncertainty")
                podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), scheduledCertainty: .uncertain)
                return DeliveryCommandResult.uncertainFailure(error: podCommsError)
            }
            if status.deliveryStatus.bolusing {
                self.log.debug("getStatus resolved bolus uncertainty (succeeded)")
                podState.unfinalizedBolus = UnfinalizedDose(bolusAmount: units, startTime: Date().addingTimeInterval(commsOffset), scheduledCertainty: .certain)
                return DeliveryCommandResult.success(statusResponse: status)
            } else {
                self.log.debug("getStatus resolved bolus uncertainty (failed)")
                return DeliveryCommandResult.certainFailure(error: podCommsError)
            }
        }
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) -> DeliveryCommandResult {
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep)

        guard podState.unfinalizedBolus?.isFinished != false else {
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
                podState.suspendState = .suspended(now)
            }

            var canceledDose: UnfinalizedDose? = nil

            if let unfinalizedTempBasal = podState.unfinalizedTempBasal,
                let finishTime = unfinalizedTempBasal.finishTime,
                deliveryType.contains(.tempBasal),
                finishTime > now
            {
                podState.unfinalizedTempBasal?.cancel(at: now)
                canceledDose = podState.unfinalizedTempBasal
                log.info("Interrupted temp basal: %@", String(describing: canceledDose))
            }

            if let unfinalizedBolus = podState.unfinalizedBolus,
                let finishTime = unfinalizedBolus.finishTime,
                deliveryType.contains(.bolus),
                finishTime > now
            {
                podState.unfinalizedBolus?.cancel(at: now, withRemaining: status.insulinNotDelivered)
                canceledDose = podState.unfinalizedBolus
                log.info("Interrupted bolus: %@", String(describing: canceledDose))
            }

            podState.updateFromStatusResponse(status)

            return CancelDeliveryResult.success(statusResponse: status, canceledDose: canceledDose)

        } catch PodCommsError.nonceResyncFailed {
            return CancelDeliveryResult.certainFailure(error: PodCommsError.nonceResyncFailed)
        } catch let error {
            podState.unfinalizedSuspend = UnfinalizedDose(suspendStartTime: Date(), scheduledCertainty: .uncertain)
            return CancelDeliveryResult.uncertainFailure(error: error as? PodCommsError ?? PodCommsError.commsError(error: error))
        }
    }

    public func testingCommands() throws {
        // try readFlashLogs()
        let _ = try cancelNone() // a functional replacement for getStatus() which also verifies & advances nonce
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
            let status = try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset)
            return status
        }
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0) throws -> StatusResponse {

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: podState.currentNonce, basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: 0)

        do {
            let status: StatusResponse = try send([basalScheduleCommand, basalExtraCommand])
            let now = Date()
            podState.suspendState = .resumed(now)
            podState.unfinalizedResume = UnfinalizedDose(resumeStartTime: now, scheduledCertainty: .certain)
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

        podState.suspendState = .resumed(Date())

        return status
    }
    
    public func cancelNone() throws -> StatusResponse {
        var statusResponse: StatusResponse

        // use cancelDelivery .none to get status AND validate & advance the nonce
        let cancelResult: CancelDeliveryResult = cancelDelivery(deliveryType: .none, beepType: .noBeep)
        switch cancelResult {
        case .certainFailure(let error):
            throw error
        case .uncertainFailure(let error):
            throw error
        case .success(let response, _):
            statusResponse = response
        }
        podState.updateFromStatusResponse(statusResponse)
        return statusResponse
    }

    @discardableResult
    public func getStatus() throws -> StatusResponse {
        if useCancelNoneForStatus {
            return try cancelNone() // functional replacement for getStatus()
        }
        let statusResponse: StatusResponse = try send([GetStatusCommand()])
        podState.updateFromStatusResponse(statusResponse)
        return statusResponse
    }

    private func readFlashLogsRequest(podInfoResponseSubType: PodInfoResponseSubType) throws {

        let blocksToSend = [GetStatusCommand(podInfoType: podInfoResponseSubType)]
        let message = Message(address: podState.address, messageBlocks: blocksToSend, sequenceNum: transport.messageNumber)
        let messageResponse = try transport.sendMessage(message)

        if let podInfoResponseMessageBlock = messageResponse.messageBlocks[0] as? PodInfoResponse {
            log.info("Pod flash log: %@", String(describing: podInfoResponseMessageBlock))
        } else if let fault = messageResponse.fault {
            handlePodFault(fault: fault)
            throw PodCommsError.podFault(fault: fault)
        } else {
            log.error("Unexpected Pod flash log response: %@", String(describing: messageResponse.messageBlocks[0]))
            throw PodCommsError.unexpectedResponse(response: messageResponse.messageBlocks[0].blockType)
        }
    }

    public func readFlashLogs() throws {
        if self.podState.fault == nil {
            let _ = try cancelNone()
            guard podState.unfinalizedBolus?.isFinished != false else {
                log.info("Unfinalized bolus, skipping read flash logs")
                throw PodCommsError.unfinalizedBolus
            }
        }

        // read up to the most recent 50 entries from flash log
        try readFlashLogsRequest(podInfoResponseSubType: .flashLogRecent)
        // read up to the previous 50 entries from flash log
        try readFlashLogsRequest(podInfoResponseSubType: .dumpOlderFlashlog)
    }

    public func deactivatePod() throws {

        if podState.fault == nil && !podState.isSuspended {
            let result = cancelDelivery(deliveryType: .all, beepType: .noBeep)
            switch result {
            case .certainFailure(let error):
                throw error
            case .uncertainFailure(let error):
                throw error
            default:
                break
            }
        }

        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)

        do {
            let _: StatusResponse = try send([deactivatePod])
        } catch let error as PodCommsError {
            switch error {
            case .podFault, .unexpectedResponse:
                break
            default:
                throw error
            }
        }
    }
    
    public func acknowledgeAlerts(alerts: AlertSet) throws -> [AlertSlot: PodAlert] {
        let cmd = AcknowledgeAlertCommand(nonce: podState.currentNonce, alerts: alerts)
        let status: StatusResponse = try send([cmd])
        podState.updateFromStatusResponse(status)
        return podState.activeAlerts
    }

    func dosesForStorage(_ storageHandler: ([UnfinalizedDose]) -> Bool) {
        assertOnSessionQueue()

        let dosesToStore = podState.dosesToStore

        if storageHandler(dosesToStore) {
            log.info("Stored doses: %@", String(describing: dosesToStore))
            self.podState.finalizedDoses.removeAll()
        }
    }

    public func assertOnSessionQueue() {
        transport.assertOnSessionQueue()
    }
}

extension PodCommsSession: MessageTransportDelegate {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: MessageTransportState) {
        messageTransport.assertOnSessionQueue()
        podState.messageTransportState = state
    }
}
