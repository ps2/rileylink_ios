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


public enum PumpCommsError: Error {
    case rfCommsFailure(String)
    case unknownPumpModel
    case rileyLinkTimeout
    case unknownResponse(rx: String, during: String)
    case noResponse(during: String)
    case unexpectedResponse(PumpMessage, from: PumpMessage)
    case crosstalk(PumpMessage, during: String)
}

public enum RXFilterMode: UInt8 {
    case wide   = 0x50  // 300KHz
    case narrow = 0x90  // 150KHz
}

class PumpOpsSynchronous {
    
    private static let standardPumpResponseWindow: UInt16 = 180
    private let expectedMaxBLELatencyMS = 1500
    
    // After
    private let minimumTimeBetweenWakeAttempts = TimeInterval(minutes: 1)
    
    let pump: PumpState
    let session: RileyLinkCmdSession
    
    init(pumpState: PumpState, session: RileyLinkCmdSession) {
        self.pump = pumpState
        self.session = session
    }
    
    private func makePumpMessage(to messageType: MessageType, using body: MessageBody = CarelinkShortMessageBody()) -> PumpMessage {
        return PumpMessage(packetType: .carelink, address: pump.pumpID, messageType: messageType, messageBody: body)
    }
    
    private func sendAndListen(_ msg: PumpMessage, timeoutMS: UInt16 = standardPumpResponseWindow, repeatCount: UInt8 = 0, msBetweenPackets: UInt8 = 0, retryCount: UInt8 = 3) throws -> PumpMessage {
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
        let singlePacketSendTime = (Double(msg.txData.count * 8) * 6 / 4 / 16384.0) * 1000
        
        let totalSendTime = Double(repeatCount) * (singlePacketSendTime + Double(timeBetweenPackets))
        
        let totalTimeout = Int(retryCount+1) * (Int(totalSendTime) + Int(timeoutMS)) + expectedMaxBLELatencyMS
        
        guard session.doCmd(cmd, withTimeoutMs: totalTimeout) else {
            throw PumpCommsError.rileyLinkTimeout
        }
        
        guard let data = cmd.receivedPacket.data else {
            if cmd.didReceiveResponse {
                throw PumpCommsError.unknownResponse(rx: cmd.rawReceivedData.hexadecimalString, during: "Sent \(msg)")
            } else {
                throw PumpCommsError.noResponse(during: "Sent \(msg)")
            }
        }
        
        guard let message = PumpMessage(rxData: data) else {
            throw PumpCommsError.unknownResponse(rx: data.hexadecimalString, during: "Sent \(msg)")
        }
        
        guard message.address == msg.address else {
            throw PumpCommsError.crosstalk(message, during: "Sent \(msg)")
        }
        
        return message
    }
    
    /**
     Attempts to send initial short wakeup message that kicks off the wakeup process.

     If successful, still does not fully wake up the pump - only alerts it such that the
     longer wakeup message can be sent next.
     */
    private func sendWakeUpBurst() throws {
        var lastError: Error?
        
        if (pump.lastWakeAttempt != nil && pump.lastWakeAttempt!.timeIntervalSinceNow > -minimumTimeBetweenWakeAttempts) {
            return
        }
        
        if pump.pumpModel == nil || !pump.pumpModel!.hasMySentry {
            // Older pumps have a longer sleep cycle between wakeups, so send an initial burst
            do {
                let shortPowerMessage = makePumpMessage(to: .powerOn)
                _ = try sendAndListen(shortPowerMessage, timeoutMS: 1, repeatCount: 255, msBetweenPackets: 0, retryCount: 0)
            }
            catch { }
        }

        do {
            let shortPowerMessage = makePumpMessage(to: .powerOn)
            let shortResponse = try sendAndListen(shortPowerMessage, timeoutMS: 12000, repeatCount: 255, msBetweenPackets: 0, retryCount: 0)

            if shortResponse.messageType == .pumpAck {
                // Pump successfully received and responded to short wakeup message!
                return
            } else {
                lastError = PumpCommsError.unexpectedResponse(shortResponse, from: shortPowerMessage)
            }
        } catch let error {
            lastError = error
        }

        pump.lastWakeAttempt = Date()

        if let lastError = lastError {
            // If all attempts failed, throw the final error
            throw lastError
        }
    }
    
    private func pumpResponding() -> Bool {
        do {
            let msg = makePumpMessage(to: .getPumpModel)
            let response = try sendAndListen(msg, retryCount: 1)
            
            if response.messageType == .getPumpModel && response.messageBody is GetPumpModelCarelinkMessageBody {
                return true
            }
        } catch {
        }
        return false
    }
    


    private func wakeup(_ duration: TimeInterval = TimeInterval(minutes: 1)) throws {
        guard !pump.isAwake else {
            return
        }
        
        if pumpResponding() {
            NSLog("Pump responding despite our wake timer having expired. Extending timer")
            // By my observations, the pump stays awake > 1 minute past last comms. Usually
            // About 1.5 minutes, but we'll make it a minute to be safe.
            pump.awakeUntil = Date(timeIntervalSinceNow: TimeInterval(minutes: 1))
            return
        }
        
        try sendWakeUpBurst()
        
        let longPowerMessage = makePumpMessage(to: .powerOn, using: PowerOnCarelinkMessageBody(duration: duration))
        let longResponse = try sendAndListen(longPowerMessage)
        
        guard longResponse.messageType == .pumpAck else {
            throw PumpCommsError.unexpectedResponse(longResponse, from: longPowerMessage)
        }
        
        NSLog("Power on for %.0f minutes", duration.minutes)
        pump.awakeUntil = Date(timeIntervalSinceNow: duration)
    }
    
    internal func runCommandWithArguments(_ msg: PumpMessage, responseMessageType: MessageType = .pumpAck) throws -> PumpMessage {
        try wakeup()
        
        let shortMsg = makePumpMessage(to: msg.messageType)
        let shortResponse = try sendAndListen(shortMsg)
        
        guard shortResponse.messageType == .pumpAck else {
            throw PumpCommsError.unexpectedResponse(shortResponse, from: shortMsg)
        }
        
        let response = try sendAndListen(msg)
        
        guard response.messageType == responseMessageType else {
            throw PumpCommsError.unexpectedResponse(response, from: msg)
        }
        
        return response
    }
    
    internal func getPumpModelNumber() throws -> String {
        let body: GetPumpModelCarelinkMessageBody = try messageBody(to: .getPumpModel)
        return body.model
    }
    
    internal func getPumpModel() throws -> PumpModel {
        if let pumpModel = pump.pumpModel {
            return pumpModel
        }

        guard let pumpModel = try PumpModel(rawValue: getPumpModelNumber()) else {
            throw PumpCommsError.unknownPumpModel
        }

        pump.pumpModel = pumpModel
        
        return pumpModel
    }
    
    internal func messageBody<T: MessageBody>(to messageType: MessageType) throws -> T {
        try wakeup()
        
        let msg = makePumpMessage(to: messageType)
        let response = try sendAndListen(msg)
        
        guard response.messageType == messageType, let body = response.messageBody as? T else {
            throw PumpCommsError.unexpectedResponse(response, from: msg)
        }
        return body
    }
    
    internal func setTempBasal(_ unitsPerHour: Double, duration: TimeInterval) throws -> ReadTempBasalCarelinkMessageBody {
        
        try wakeup()
        var lastError: Error?
        
        let changeMessage = PumpMessage(packetType: .carelink, address: pump.pumpID, messageType: .changeTempBasal, messageBody: ChangeTempBasalCarelinkMessageBody(unitsPerHour: unitsPerHour, duration: duration))
        
        for attempt in 0..<3 {
            do {
                _ = try sendAndListen(makePumpMessage(to: changeMessage.messageType))
                
                do {
                    _ = try sendAndListen(changeMessage, retryCount: 0)
                } catch {
                    // The pump does not ACK a temp basal. We'll check manually below if it was successful.
                }
                
                let response: ReadTempBasalCarelinkMessageBody = try messageBody(to: .readTempBasal)
                
                if response.timeRemaining == duration && response.rateType == .absolute {
                    return response
                } else {
                    lastError = PumpCommsError.rfCommsFailure("Could not verify TempBasal on attempt \(attempt)")
                }
            } catch let error {
                lastError = error
            }
        }
        
        throw lastError!
    }
    
    internal func changeTime(_ messageGenerator: () -> PumpMessage) throws {
        try wakeup()

        let shortMessage = makePumpMessage(to: .changeTime)
        let shortResponse = try sendAndListen(shortMessage)
        
        guard shortResponse.messageType == .pumpAck else {
            throw PumpCommsError.unexpectedResponse(shortResponse, from: shortMessage)
        }

        let message = messageGenerator()
        let response = try sendAndListen(message)
        
        guard response.messageType == .pumpAck else {
            throw PumpCommsError.unexpectedResponse(response, from: message)
        }
    }

    internal func changeWatchdogMarriageProfile(_ watchdogID: Data) throws {
        let commandTimeoutMS: UInt16 = 30_000

        // Wait for the pump to start polling
        let listenForFindMessageCmd = GetPacketCmd()
        listenForFindMessageCmd.listenChannel = 0
        listenForFindMessageCmd.timeoutMS = commandTimeoutMS

        guard session.doCmd(listenForFindMessageCmd, withTimeoutMs: Int(commandTimeoutMS) + expectedMaxBLELatencyMS) else {
            throw PumpCommsError.rileyLinkTimeout
        }
        
        guard let data = listenForFindMessageCmd.receivedPacket.data else {
            throw PumpCommsError.noResponse(during: "Watchdog listening")
        }
            
        guard let findMessage = PumpMessage(rxData: data), findMessage.address.hexadecimalString == pump.pumpID && findMessage.packetType == .mySentry,
            let findMessageBody = findMessage.messageBody as? FindDeviceMessageBody, let findMessageResponseBody = MySentryAckMessageBody(sequence: findMessageBody.sequence, watchdogID: watchdogID, responseMessageTypes: [findMessage.messageType])
        else {
            throw PumpCommsError.unknownResponse(rx: data.hexadecimalString, during: "Watchdog listening")
        }

        // Identify as a MySentry device
        let findMessageResponse = PumpMessage(packetType: .mySentry, address: pump.pumpID, messageType: .pumpAck, messageBody: findMessageResponseBody)

        let linkMessage = try sendAndListen(findMessageResponse, timeoutMS: commandTimeoutMS)

        guard let
            linkMessageBody = linkMessage.messageBody as? DeviceLinkMessageBody,
            let linkMessageResponseBody = MySentryAckMessageBody(sequence: linkMessageBody.sequence, watchdogID: watchdogID, responseMessageTypes: [linkMessage.messageType])
        else {
            throw PumpCommsError.unexpectedResponse(linkMessage, from: findMessageResponse)
        }

        // Acknowledge the pump linked with us
        let linkMessageResponse = PumpMessage(packetType: .mySentry, address: pump.pumpID, messageType: .pumpAck, messageBody: linkMessageResponseBody)

        let cmd = SendPacketCmd()
        cmd.packet = RFPacket(data: linkMessageResponse.txData)
        session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
    }

    internal func setRXFilterMode(_ mode: RXFilterMode) throws {
        let drate_e = UInt8(0x9) // exponent of symbol rate (16kbps)
        let chanbw = mode.rawValue
        try updateRegister(UInt8(CC111X_REG_MDMCFG4), value: chanbw | drate_e)
    }
    
    func configureRadio(for region: PumpRegion) throws {
        switch region {
        case .worldWide:
            try updateRegister(UInt8(CC111X_REG_MDMCFG4), value: 0x59)
            //try updateRegister(UInt8(CC111X_REG_MDMCFG3), value: 0x66)
            //try updateRegister(UInt8(CC111X_REG_MDMCFG2), value: 0x33)
            try updateRegister(UInt8(CC111X_REG_MDMCFG1), value: 0x62)
            try updateRegister(UInt8(CC111X_REG_MDMCFG0), value: 0x1A)
            try updateRegister(UInt8(CC111X_REG_DEVIATN), value: 0x13)
        case .northAmerica:
            try updateRegister(UInt8(CC111X_REG_MDMCFG4), value: 0x99)
            //try updateRegister(UInt8(CC111X_REG_MDMCFG3), value: 0x66)
            //try updateRegister(UInt8(CC111X_REG_MDMCFG2), value: 0x33)
            try updateRegister(UInt8(CC111X_REG_MDMCFG1), value: 0x61)
            try updateRegister(UInt8(CC111X_REG_MDMCFG0), value: 0x7E)
            try updateRegister(UInt8(CC111X_REG_DEVIATN), value: 0x15)
        }
    }
    
    private func updateRegister(_ addr: UInt8, value: UInt8) throws {
        let cmd = UpdateRegisterCmd()
        cmd.addr = addr;
        cmd.value = value;
        if !session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
            throw PumpCommsError.rileyLinkTimeout
        }
    }
    
    internal func setBaseFrequency(_ freqMHz: Double) throws {
        let val = Int((freqMHz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
        
        try updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
        try updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
        NSLog("Set frequency to %f", freqMHz)
    }
    
    internal func tuneRadio(for region: PumpRegion) throws -> FrequencyScanResults {
        
        let scanFrequencies: [Double]
        
        switch region {
        case .worldWide:
            scanFrequencies = [868.25, 868.30, 868.35, 868.40, 868.45, 868.50, 868.55, 868.60, 868.65]
        case .northAmerica:
            scanFrequencies = [916.45, 916.50, 916.55, 916.60, 916.65, 916.70, 916.75, 916.80]
        }
        
        return try scanForPump(in: scanFrequencies)
    }
    
    internal func scanForPump(in frequencies: [Double]) throws -> FrequencyScanResults {
        
        var results = FrequencyScanResults()
        
        let middleFreq = frequencies[frequencies.count / 2]
        
        do {
            // Needed to put the pump in listen mode
            try setBaseFrequency(middleFreq)
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
                let msg = makePumpMessage(to: .getPumpModel)
                let cmd = SendAndListenCmd()
                cmd.packet = RFPacket(data: msg.txData)
                cmd.timeoutMS = type(of: self).standardPumpResponseWindow
                if session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
                    if let data =  cmd.receivedPacket.data,
                        let response = PumpMessage(rxData: data), response.messageType == .getPumpModel {
                        sumRSSI += Int(cmd.receivedPacket.rssi)
                        trial.successes += 1
                    }
                } else {
                    throw PumpCommsError.rileyLinkTimeout
                }
                trial.tries += 1
            }
            // Mark each failure as a -99 rssi, so we can use highest rssi as best freq
            sumRSSI += -99 * (trial.tries - trial.successes)
            trial.avgRSSI = Double(sumRSSI) / Double(trial.tries)
            results.trials.append(trial)
        }
        let sortedTrials = results.trials.sorted(by: { (a, b) -> Bool in
            return a.avgRSSI > b.avgRSSI
        })
        if sortedTrials.first!.successes > 0 {
            results.bestFrequency = sortedTrials.first!.frequencyMHz
            try setBaseFrequency(results.bestFrequency)
        } else {
            try setBaseFrequency(middleFreq)
            throw PumpCommsError.rfCommsFailure("No pump responses during scan")
        }
        
        return results
    }
    
    internal func getHistoryEvents(since startDate: Date) throws -> ([TimestampedHistoryEvent], PumpModel) {
        try wakeup()
        
        let pumpModel = try getPumpModel()
        
        var events = [TimestampedHistoryEvent]()
        var timeAdjustmentInterval: TimeInterval = 0
        
        // Going to scan backwards in time through events, so event time should be monotonically decreasing.
        // Exceptions are Square Wave boluses, which can be out of order in the pump history by up
        // to 8 hours on older pumps, and Normal Boluses, which can be out of order by roughly 4 minutes.
        let eventTimestampDeltaAllowance: TimeInterval
        if pumpModel.appendsSquareWaveToHistoryOnStartOfDelivery {
            eventTimestampDeltaAllowance = TimeInterval(minutes: 10)
        } else {
            eventTimestampDeltaAllowance = TimeInterval(hours: 9)
        }

        // Start with some time in the future, to account for the condition when the pump's clock is ahead
        // of ours by a small amount.
        var timeCursor = Date(timeIntervalSinceNow: TimeInterval(minutes: 60))
        
        // Prevent returning duplicate content, which is possible e.g. in the case of rapid RF temp basal setting
        var seenEventData = Set<Data>()
        var lastEvent: PumpEvent?
        
        pages: for pageNum in 0..<16 {
            NSLog("Fetching page %d", pageNum)
            let pageData: Data

            do {
                pageData = try getHistoryPage(pageNum)
            } catch let error as PumpCommsError {
                if case .unexpectedResponse(let response, from: _) = error, response.messageType == .emptyHistoryPage {
                    break pages
                } else {
                    throw error
                }
            }
            
            var idx = 0
            let chunkSize = 256;
            while idx < pageData.count {
                let top = min(idx + chunkSize, pageData.count)
                let range = Range(uncheckedBounds: (lower: idx, upper: top))
                NSLog(String(format: "HistoryPage %02d - (bytes %03d-%03d): ", pageNum, idx, top-1) + pageData.subdata(in: range).hexadecimalString)
                idx = top
            }

            let page = try HistoryPage(pageData: pageData, pumpModel: pumpModel)

            for event in page.events.reversed() {
                if let event = event as? TimestampedPumpEvent, !seenEventData.contains(event.rawData) {
                    seenEventData.insert(event.rawData)

                    var timestamp = event.timestamp
                    timestamp.timeZone = pump.timeZone

                    if let date = timestamp.date?.addingTimeInterval(timeAdjustmentInterval) {
                        if date.timeIntervalSince(startDate) < -eventTimestampDeltaAllowance {
                            NSLog("Found event at (%@) to be more than %@s before startDate(%@)", date as NSDate, String(describing: eventTimestampDeltaAllowance), startDate as NSDate);
                            break pages
                        } else if date.timeIntervalSince(timeCursor) > eventTimestampDeltaAllowance {
                            NSLog("Found event (%@) out of order in history. Ending history fetch.", date as NSDate)
                            break pages
                        } else {
                            if (date.compare(startDate) != .orderedAscending) {
                                timeCursor = date
                            }
                            events.insert(TimestampedHistoryEvent(pumpEvent: event, date: date), at: 0)
                        }
                    }
                }

                if let changeTimeEvent = event as? ChangeTimePumpEvent, let newTimeEvent = lastEvent as? NewTimePumpEvent {
                    timeAdjustmentInterval += (newTimeEvent.timestamp.date?.timeIntervalSince(changeTimeEvent.timestamp.date!))!
                }

                lastEvent = event
            }
        }
        return (events, pumpModel)
    }
    
    private func getHistoryPage(_ pageNum: Int) throws -> Data {
        var frameData = Data()
        
        let msg = makePumpMessage(to: .getHistoryPage, using: GetHistoryPageCarelinkMessageBody(pageNum: pageNum))
        
        let firstResponse = try runCommandWithArguments(msg, responseMessageType: .getHistoryPage)

        var expectedFrameNum = 1
        var curResp = firstResponse.messageBody as! GetHistoryPageCarelinkMessageBody
        
        while(expectedFrameNum == curResp.frameNumber) {
            frameData.append(curResp.frame)
            expectedFrameNum += 1
            let msg = makePumpMessage(to: .pumpAck)
            if !curResp.lastFrame {
                guard let resp = try? sendAndListen(msg) else {
                    throw PumpCommsError.rfCommsFailure("Did not receive frame data from pump")
                }
                guard resp.packetType == .carelink && resp.messageType == .getHistoryPage else {
                    throw PumpCommsError.rfCommsFailure("Bad packet type or message type. Possible interference.")
                }
                curResp = resp.messageBody as! GetHistoryPageCarelinkMessageBody
            } else {
                let cmd = SendPacketCmd()
                cmd.packet = RFPacket(data: msg.txData)
                session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
                break
            }
        }
        
        guard frameData.count == 1024 else {
            throw PumpCommsError.rfCommsFailure("Short history page: \(frameData.count) bytes. Expected 1024")
        }
        return frameData as Data
    }
    
    internal func logGlucoseHistory(pageData: Data, pageNum: Int) {
        var idx = 0
        let chunkSize = 256;
        while idx < pageData.count {
            let top = min(idx + chunkSize, pageData.count)
            let range = Range(uncheckedBounds: (lower: idx, upper: top))
            NSLog(String(format: "GlucosePage %02d - (bytes %03d-%03d): ", pageNum, idx, top-1) + pageData.subdata(in: range).hexadecimalString)
            idx = top
        }
    }
    
    internal func getGlucoseHistoryEvents(since startDate: Date) throws -> [TimestampedGlucoseEvent] {
        try wakeup()
        
        var events = [TimestampedGlucoseEvent]()
        
        let currentGlucosePage = try readCurrentGlucosePage()
        let startPage = Int(currentGlucosePage.pageNum)
        //max lookback of 15 pages or when page is 0
        let endPage = max(startPage - 15, 0)
        
        pages: for pageNum in stride(from: startPage, to: endPage - 1, by: -1) {
            NSLog("Fetching page %d", pageNum)
            var pageData: Data
            var page: GlucosePage
            
            do {
                pageData = try getGlucosePage(UInt32(pageNum))
                logGlucoseHistory(pageData: pageData, pageNum: pageNum)
                page = try GlucosePage(pageData: pageData)
                
                if page.needsTimestamp && pageNum == startPage {
                    NSLog(String(format: "GlucosePage %02d needs a new sensor timestamp, writing...", pageNum))
                    let _ = try writeGlucoseHistoryTimestamp()
                    
                    //fetch page again with new sensor timestamp
                    pageData = try getGlucosePage(UInt32(pageNum))
                    logGlucoseHistory(pageData: pageData, pageNum: pageNum)
                    page = try GlucosePage(pageData: pageData)
                }
                
            } catch let error as PumpCommsError {
                if case .unexpectedResponse(let response, from: _) = error, response.messageType == .emptyHistoryPage {
                    break pages
                } else {
                    throw error
                }
            }
            
            for event in page.events.reversed() {
                var timestamp = event.timestamp
                timestamp.timeZone = pump.timeZone
                
                if event is UnknownGlucoseEvent {
                    continue pages
                }
                
                if let date = timestamp.date {
                    if date < startDate && event is SensorTimestampGlucoseEvent {
                        NSLog("Found reference event at (%@) to be before startDate(%@)", date as NSDate, startDate as NSDate);
                        break pages
                    } else {
                        events.insert(TimestampedGlucoseEvent(glucoseEvent: event, date: date), at: 0)
                    }
                }
            }
        }
        return events
    }

    private func readCurrentGlucosePage() throws -> ReadCurrentGlucosePageMessageBody {
        let readCurrentGlucosePageResponse: ReadCurrentGlucosePageMessageBody = try messageBody(to: .readCurrentGlucosePage)
        
        return readCurrentGlucosePageResponse
    }

    private func getGlucosePage(_ pageNum: UInt32) throws -> Data {
        var frameData = Data()
        
        let msg = makePumpMessage(to: .getGlucosePage, using: GetGlucosePageMessageBody(pageNum: pageNum))
        
        let firstResponse = try runCommandWithArguments(msg, responseMessageType: .getGlucosePage)
        
        var expectedFrameNum = 1
        var curResp = firstResponse.messageBody as! GetGlucosePageMessageBody
        
        while(expectedFrameNum == curResp.frameNumber) {
            frameData.append(curResp.frame)
            expectedFrameNum += 1
            let msg = makePumpMessage(to: .pumpAck)
            if !curResp.lastFrame {
                guard let resp = try? sendAndListen(msg) else {
                    throw PumpCommsError.rfCommsFailure("Did not receive frame data from pump")
                }
                guard resp.packetType == .carelink && resp.messageType == .getGlucosePage else {
                    throw PumpCommsError.rfCommsFailure("Bad packet type or message type. Possible interference.")
                }
                curResp = resp.messageBody as! GetGlucosePageMessageBody
            } else {
                let cmd = SendPacketCmd()
                cmd.packet = RFPacket(data: msg.txData)
                session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
                break
            }
        }
        
        guard frameData.count == 1024 else {
            throw PumpCommsError.rfCommsFailure("Short glucose history page: \(frameData.count) bytes. Expected 1024")
        }
        return frameData as Data
    }
    
    internal func writeGlucoseHistoryTimestamp() throws -> Void {
        let shortWriteTimestamp = makePumpMessage(to: .writeGlucoseHistoryTimestamp)
        let shortResponse = try sendAndListen(shortWriteTimestamp, timeoutMS: 12000, repeatCount: 255, msBetweenPackets: 0, retryCount: 0)
        
        if shortResponse.messageType == .pumpAck {
            return
        } else {
            throw PumpCommsError.unexpectedResponse(shortResponse, from: shortWriteTimestamp)
        }
    }

    internal func readPumpStatus() throws -> PumpStatus {
        let clockResp: ReadTimeCarelinkMessageBody = try messageBody(to: .readTime)

        let pumpModel = try getPumpModel()

        let resResp: ReadRemainingInsulinMessageBody = try messageBody(to: .readRemainingInsulin)

        let reservoir = resResp.getUnitsRemainingForStrokes(pumpModel.strokesPerUnit)

        let battResp: GetBatteryCarelinkMessageBody = try messageBody(to: .getBattery)

        let statusResp: ReadPumpStatusMessageBody = try messageBody(to: .readPumpStatus)

        return PumpStatus(clock: clockResp.dateComponents, batteryVolts: battResp.volts, batteryStatus: battResp.status, suspended: statusResp.suspended, bolusing: statusResp.bolusing, reservoir: reservoir, model: pumpModel, pumpID: pump.pumpID)

    }
}

public struct PumpStatus {
    public let clock: DateComponents
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
