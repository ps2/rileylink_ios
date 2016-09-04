//
//  PumpOpsSynchronous.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkBLEKit


public enum PumpCommsError: ErrorType {
    case RFCommsFailure(String)
    case UnknownPumpModel
    case RileyLinkTimeout
    case UnknownResponse(rx: NSString, during: String)
    case NoResponse(during: String)
    case UnexpectedResponse(PumpMessage, from: PumpMessage)
    case Crosstalk(PumpMessage, during: String)
}

public enum RXFilterMode: UInt8 {
    case Wide   = 0x50  // 300KHz
    case Narrow = 0x90  // 150KHz
}

class PumpOpsSynchronous {
    
    private static let standardPumpResponseWindow: UInt16 = 180
    private let expectedMaxBLELatencyMS = 1500
    
    // After
    private let minimumTimeBetweenWakeAttempts = NSTimeInterval(minutes: 1)
    
    let pump: PumpState
    let session: RileyLinkCmdSession
    
    init(pumpState: PumpState, session: RileyLinkCmdSession) {
        self.pump = pumpState
        self.session = session
    }
    
    private func makePumpMessage(messageType: MessageType, body: MessageBody = CarelinkShortMessageBody()) -> PumpMessage {
        return PumpMessage(packetType: .Carelink, address: pump.pumpID, messageType: messageType, messageBody: body)
    }
    
    private func sendAndListen(msg: PumpMessage, timeoutMS: UInt16 = standardPumpResponseWindow, repeatCount: UInt8 = 0, msBetweenPackets: UInt8 = 0, retryCount: UInt8 = 3) throws -> PumpMessage {
        let cmd = SendAndListenCmd()
        cmd.packet = RFPacket(data: msg.txData)
        cmd.timeoutMS = timeoutMS
        cmd.repeatCount = repeatCount
        cmd.msBetweenPackets = msBetweenPackets
        cmd.retryCount = retryCount
        cmd.listenChannel = 0
        
        let minTimeBetweenPackets = 12 // At least 12 ms between packets for radio to stop/start
        
        let timeBetweenPackets = max(minTimeBetweenPackets, Int(msBetweenPackets))
        
        // 16384 = bitrate, 8 = bits per byte, 6/4 = 4b6 encoding, 1000 = ms in 1s
        let singlePacketSendTime = (Double(msg.txData.length * 8) * 6 / 4 / 16384.0) * 1000
        
        let totalSendTime = Double(repeatCount) * (singlePacketSendTime + Double(timeBetweenPackets))
        
        let totalTimeout = Int(retryCount+1) * (Int(totalSendTime) + Int(timeoutMS)) + expectedMaxBLELatencyMS
        
        guard session.doCmd(cmd, withTimeoutMs: totalTimeout) else {
            throw PumpCommsError.RileyLinkTimeout
        }
        
        guard let data = cmd.receivedPacket.data else {
            if cmd.didReceiveResponse {
                throw PumpCommsError.UnknownResponse(rx: cmd.rawReceivedData.hexadecimalString, during: "Sent \(msg)")
            } else {
                throw PumpCommsError.NoResponse(during: "Sent \(msg)")
            }
        }
        
        guard let message = PumpMessage(rxData: data) else {
            throw PumpCommsError.UnknownResponse(rx: data.hexadecimalString, during: "Sent \(msg)")
        }
        
        guard message.address == msg.address else {
            throw PumpCommsError.Crosstalk(message, during: "Sent \(msg)")
        }
        
        return message
    }
    
    /**
     Attempts to send initial short wakeup message that kicks off the wakeup process.

     If successful, still does not fully wake up the pump - only alerts it such that the
     longer wakeup message can be sent next.
     */
    private func attemptShortWakeUp(attempts: Int = 3) throws {
        var lastError: ErrorType?
        
        if (pump.lastWakeAttempt != nil && pump.lastWakeAttempt!.timeIntervalSinceNow > -minimumTimeBetweenWakeAttempts) {
            return
        }
        
        
        if pump.pumpModel == nil || !pump.pumpModel!.hasMySentry {
            // Older pumps have a longer sleep cycle between wakeups, so send an initial burst
            do {
                let shortPowerMessage = makePumpMessage(.PowerOn)
                try sendAndListen(shortPowerMessage, timeoutMS: 1, repeatCount: 255, msBetweenPackets: 0, retryCount: 0)
            }
            catch { }
        }

        do {
            let shortPowerMessage = makePumpMessage(.PowerOn)
            let shortResponse = try sendAndListen(shortPowerMessage, timeoutMS: 12000, repeatCount: 255, msBetweenPackets: 0, retryCount: 0)

            if shortResponse.messageType == .PumpAck {
                // Pump successfully received and responded to short wakeup message!
                return
            } else {
                lastError = PumpCommsError.UnexpectedResponse(shortResponse, from: shortPowerMessage)
            }
        } catch let error {
            lastError = error
        }

        pump.lastWakeAttempt = NSDate()

        if let lastError = lastError {
            // If all attempts failed, throw the final error
            throw lastError
        }
    }

    private func wakeup(duration: NSTimeInterval = NSTimeInterval(minutes: 1)) throws {
        guard !pump.isAwake else {
            return
        }
        
        try attemptShortWakeUp()
        
        let longPowerMessage = makePumpMessage(.PowerOn, body: PowerOnCarelinkMessageBody(duration: duration))
        let longResponse = try sendAndListen(longPowerMessage)
        
        guard longResponse.messageType == .PumpAck else {
            throw PumpCommsError.UnexpectedResponse(longResponse, from: longPowerMessage)
        }
        
        NSLog("Power on for %.0f minutes", duration.minutes)
        pump.awakeUntil = NSDate(timeIntervalSinceNow: duration)
    }
    
    internal func runCommandWithArguments(msg: PumpMessage, responseMessageType: MessageType = .PumpAck) throws -> PumpMessage {
        try wakeup()
        
        let shortMsg = makePumpMessage(msg.messageType)
        let shortResponse = try sendAndListen(shortMsg)
        
        guard shortResponse.messageType == .PumpAck else {
            throw PumpCommsError.UnexpectedResponse(shortResponse, from: shortMsg)
        }
        
        let response = try sendAndListen(msg)
        
        guard response.messageType == responseMessageType else {
            throw PumpCommsError.UnexpectedResponse(response, from: msg)
        }
        
        return response
    }
    
    internal func getPumpModelNumber() throws -> String {
        let body: GetPumpModelCarelinkMessageBody = try getMessageBodyWithType(.GetPumpModel)
        return body.model
    }
    
    internal func getPumpModel() throws -> PumpModel {
        if let pumpModel = pump.pumpModel {
            return pumpModel
        }

        guard let pumpModel = try PumpModel(rawValue: getPumpModelNumber()) else {
            throw PumpCommsError.UnknownPumpModel
        }

        pump.pumpModel = pumpModel
        
        return pumpModel
    }
    
    internal func getMessageBodyWithType<T: MessageBody>(messageType: MessageType) throws -> T {
        try wakeup()
        
        let msg = makePumpMessage(messageType)
        let response = try sendAndListen(msg)
        
        guard response.messageType == messageType, let body = response.messageBody as? T else {
            throw PumpCommsError.UnexpectedResponse(response, from: msg)
        }
        return body
    }
    
    internal func setTempBasal(unitsPerHour: Double, duration: NSTimeInterval) throws -> ReadTempBasalCarelinkMessageBody {
        
        try wakeup()
        var lastError: ErrorType?
        
        let changeMessage = PumpMessage(packetType: .Carelink, address: pump.pumpID, messageType: .ChangeTempBasal, messageBody: ChangeTempBasalCarelinkMessageBody(unitsPerHour: unitsPerHour, duration: duration))
        
        for attempt in 0..<3 {
            do {
                try sendAndListen(makePumpMessage(changeMessage.messageType))
                
                do {
                    try sendAndListen(changeMessage, retryCount: 0)
                } catch {
                    // The pump does not ACK a temp basal. We'll check manually below if it was successful.
                }
                
                let response: ReadTempBasalCarelinkMessageBody = try getMessageBodyWithType(.ReadTempBasal)
                
                if response.timeRemaining == duration && response.rateType == .Absolute {
                    return response
                } else {
                    lastError = PumpCommsError.RFCommsFailure("Could not verify TempBasal on attempt \(attempt)")
                }
            } catch let error {
                lastError = error
            }
        }
        
        throw lastError!
    }
    
    internal func changeTime(messageGenerator: () -> PumpMessage) throws {
        try wakeup()

        let shortMessage = makePumpMessage(.ChangeTime)
        let shortResponse = try sendAndListen(shortMessage)
        
        guard shortResponse.messageType == .PumpAck else {
            throw PumpCommsError.UnexpectedResponse(shortResponse, from: shortMessage)
        }

        let message = messageGenerator()
        let response = try sendAndListen(message)
        
        guard response.messageType == .PumpAck else {
            throw PumpCommsError.UnexpectedResponse(response, from: message)
        }
    }

    internal func changeWatchdogMarriageProfile(watchdogID: NSData) throws {
        let commandTimeoutMS: UInt16 = 30_000

        // Wait for the pump to start polling
        let listenForFindMessageCmd = GetPacketCmd()
        listenForFindMessageCmd.listenChannel = 0
        listenForFindMessageCmd.timeoutMS = commandTimeoutMS

        guard session.doCmd(listenForFindMessageCmd, withTimeoutMs: Int(commandTimeoutMS) + expectedMaxBLELatencyMS) else {
            throw PumpCommsError.RileyLinkTimeout
        }
        
        guard let data = listenForFindMessageCmd.receivedPacket.data else {
            throw PumpCommsError.NoResponse(during: "Watchdog listening")
        }
            
        guard let findMessage = PumpMessage(rxData: data) where findMessage.address.hexadecimalString == pump.pumpID && findMessage.packetType == .MySentry,
            let findMessageBody = findMessage.messageBody as? FindDeviceMessageBody, findMessageResponseBody = MySentryAckMessageBody(sequence: findMessageBody.sequence, watchdogID: watchdogID, responseMessageTypes: [findMessage.messageType])
        else {
            throw PumpCommsError.UnknownResponse(rx: data.hexadecimalString, during: "Watchdog listening")
        }

        // Identify as a MySentry device
        let findMessageResponse = PumpMessage(packetType: .MySentry, address: pump.pumpID, messageType: .PumpAck, messageBody: findMessageResponseBody)

        let linkMessage = try sendAndListen(findMessageResponse, timeoutMS: commandTimeoutMS)

        guard let
            linkMessageBody = linkMessage.messageBody as? DeviceLinkMessageBody,
            linkMessageResponseBody = MySentryAckMessageBody(sequence: linkMessageBody.sequence, watchdogID: watchdogID, responseMessageTypes: [linkMessage.messageType])
        else {
            throw PumpCommsError.UnexpectedResponse(linkMessage, from: findMessageResponse)
        }

        // Acknowledge the pump linked with us
        let linkMessageResponse = PumpMessage(packetType: .MySentry, address: pump.pumpID, messageType: .PumpAck, messageBody: linkMessageResponseBody)

        let cmd = SendPacketCmd()
        cmd.packet = RFPacket(data: linkMessageResponse.txData)
        session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
    }

    internal func setRXFilterMode(mode: RXFilterMode) throws {
        let drate_e = UInt8(0x9) // exponent of symbol rate (16kbps)
        let chanbw = mode.rawValue
        try updateRegister(UInt8(CC111X_REG_MDMCFG4), value: chanbw | drate_e)
    }
    
    private func updateRegister(addr: UInt8, value: UInt8) throws {
        let cmd = UpdateRegisterCmd()
        cmd.addr = addr;
        cmd.value = value;
        if !session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
            throw PumpCommsError.RileyLinkTimeout
        }
    }
    
    internal func setBaseFrequency(freqMHz: Double) throws {
        let val = Int((freqMHz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
        
        try updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
        NSLog("Set frequency to %f", freqMHz)
    }
    
    internal func scanForPump(frequencies: [Double]) throws -> FrequencyScanResults {
        
        var results = FrequencyScanResults()
        
        do {
            // Needed to put the pump in listen mode
            try wakeup()
        } catch {
            // Continue anyway; the pump likely heard us, even if we didn't hear it.
        }
        
        for freq in frequencies {
            let tries = 3
            var trial = FrequencyTrial()
            trial.frequencyMHz = freq
            try setBaseFrequency(freq)
            var sumRSSI = 0
            for _ in 1...tries {
                let msg = makePumpMessage(.GetPumpModel)
                let cmd = SendAndListenCmd()
                cmd.packet = RFPacket(data: msg.txData)
                cmd.timeoutMS = self.dynamicType.standardPumpResponseWindow
                if session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
                    if let data =  cmd.receivedPacket.data,
                        let response = PumpMessage(rxData: data) where response.messageType == .GetPumpModel {
                        sumRSSI += Int(cmd.receivedPacket.rssi)
                        trial.successes += 1
                    }
                } else {
                    throw PumpCommsError.RileyLinkTimeout
                }
                trial.tries += 1
            }
            // Mark each failure as a -99 rssi, so we can use highest rssi as best freq
            sumRSSI += -99 * (trial.tries - trial.successes)
            trial.avgRSSI = Double(sumRSSI) / Double(trial.tries)
            results.trials.append(trial)
        }
        let sortedTrials = results.trials.sort({ (a, b) -> Bool in
            return a.avgRSSI > b.avgRSSI
        })
        if sortedTrials.first!.successes > 0 {
            results.bestFrequency = sortedTrials.first!.frequencyMHz
            try setBaseFrequency(results.bestFrequency)
        } else {
            throw PumpCommsError.RFCommsFailure("No pump responses during scan")
        }
        
        return results
    }
    
    internal func getHistoryEventsSinceDate(startDate: NSDate) throws -> ([TimestampedHistoryEvent], PumpModel) {
        try wakeup()
        
        let pumpModel = try getPumpModel()

        var events = [TimestampedHistoryEvent]()
        var timeAdjustmentInterval: NSTimeInterval = 0
        
        // Going to scan backwards in time through events, so event time should be monotonically decreasing.
        // Exceptions are Square Wave boluses, which can be out of order in the pump history by up
        // to 8 hours on older pumps, and Normal Boluses, which can be out of order by roughly 4 minutes.
        let eventTimestampDeltaAllowance: NSTimeInterval
        if pumpModel.appendsSquareWaveToHistoryOnStartOfDelivery {
            eventTimestampDeltaAllowance = NSTimeInterval(minutes: 10)
        } else {
            eventTimestampDeltaAllowance = NSTimeInterval(hours: 9)
        }

        // Start with some time in the future, to account for the condition when the pump's clock is ahead
        // of ours by a small amount.
        var timeCursor = NSDate(timeIntervalSinceNow: NSTimeInterval(minutes: 60))
        

        pages: for pageNum in 0..<16 {
            NSLog("Fetching page %d", pageNum)
            let pageData: NSData

            do {
                pageData = try getHistoryPage(pageNum)
            } catch let error as PumpCommsError {
                if case .UnexpectedResponse(let response, from: _) = error where response.messageType == .EmptyHistoryPage {
                    break pages
                } else {
                    throw error
                }
            }
            
            NSLog("Fetched page %d: %@", pageNum, pageData)
            let page = try HistoryPage(pageData: pageData, pumpModel: pumpModel)

            for event in page.events.reverse() {
                if let event = event as? TimestampedPumpEvent {
                    let timestamp = event.timestamp
                    timestamp.timeZone = pump.timeZone

                    if let date = timestamp.date?.dateByAddingTimeInterval(timeAdjustmentInterval) {
                        if date.timeIntervalSinceDate(startDate) < -eventTimestampDeltaAllowance {
                            NSLog("Found event at (%@) to be more than %@s before startDate(%@)", date, String(eventTimestampDeltaAllowance), startDate);
                            break pages
                        } else if date.timeIntervalSinceDate(timeCursor) > eventTimestampDeltaAllowance {
                            NSLog("Found event (%@) out of order in history. Ending history fetch.", date)
                            break pages
                        } else if date.compare(startDate) != .OrderedAscending {
                            timeCursor = date
                            events.insert(TimestampedHistoryEvent(pumpEvent: event, date: date), atIndex: 0)
                        }
                    }
                }

                if let event = event as? ChangeTimePumpEvent {
                    timeAdjustmentInterval += event.adjustmentInterval
                }
            }
        }
        return (events, pumpModel)
    }
    
    private func getHistoryPage(pageNum: Int) throws -> NSData {
        let frameData = NSMutableData()
        
        let msg = makePumpMessage(.GetHistoryPage, body: GetHistoryPageCarelinkMessageBody(pageNum: pageNum))
        
        let firstResponse = try runCommandWithArguments(msg, responseMessageType: .GetHistoryPage)

        var expectedFrameNum = 1
        var curResp = firstResponse.messageBody as! GetHistoryPageCarelinkMessageBody
        
        while(expectedFrameNum == curResp.frameNumber) {
            frameData.appendData(curResp.frame)
            expectedFrameNum += 1
            let msg = makePumpMessage(.PumpAck)
            if !curResp.lastFrame {
                guard let resp = try? sendAndListen(msg) else {
                    throw PumpCommsError.RFCommsFailure("Did not receive frame data from pump")
                }
                guard resp.packetType == .Carelink && resp.messageType == .GetHistoryPage else {
                    throw PumpCommsError.RFCommsFailure("Bad packet type or message type. Possible interference.")
                }
                curResp = resp.messageBody as! GetHistoryPageCarelinkMessageBody
            } else {
                let cmd = SendPacketCmd()
                cmd.packet = RFPacket(data: msg.txData)
                session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
                break
            }
        }
        
        guard frameData.length == 1024 else {
            throw PumpCommsError.RFCommsFailure("Short history page: " + String(frameData.length) + " bytes. Expected 1024")
        }
        return frameData
    }

    internal func readPumpStatus() throws -> PumpStatus {
        let clockResp: ReadTimeCarelinkMessageBody = try getMessageBodyWithType(.ReadTime)

        let pumpModel = try getPumpModel()

        let resResp: ReadRemainingInsulinMessageBody = try getMessageBodyWithType(.ReadRemainingInsulin)

        let reservoir = resResp.getUnitsRemainingForStrokes(pumpModel.strokesPerUnit)

        let battResp: GetBatteryCarelinkMessageBody = try getMessageBodyWithType(.GetBattery)

        let statusResp: ReadPumpStatusMessageBody = try getMessageBodyWithType(.ReadPumpStatus)

        return PumpStatus(clock: clockResp.dateComponents, batteryVolts: battResp.volts, batteryStatus: battResp.status, suspended: statusResp.suspended, bolusing: statusResp.bolusing, reservoir: reservoir, model: pumpModel, pumpID: pump.pumpID)

    }
}

public struct PumpStatus {
    public let clock: NSDateComponents
    public let batteryVolts: Double
    public let batteryStatus: BatteryStatus
    public let suspended: Bool
    public let bolusing: Bool
    public let reservoir: Double
    public let model: PumpModel
    public let pumpID: String
}

public struct FrequencyTrial {
    public var tries: Int = 0
    public var successes: Int = 0
    public var avgRSSI: Double = -99
    public var frequencyMHz: Double = 0
}

public struct FrequencyScanResults {
    public var trials = [FrequencyTrial]()
    public var bestFrequency: Double = 0
}
