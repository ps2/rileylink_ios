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
}

fileprivate let defaultAddress: UInt32 = 0xffffffff


public protocol PodCommsSessionDelegate: class {
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState?)
}

public class PodCommsSession {
    
    var packetNumber = 0
    var messageNumber = 0
    
    private var podState: PodState? {
        didSet {
            print("PodCommsSession.didChange podState: \(String(describing: podState))")
            delegate.podCommsSession(self, didChange: podState)
        }
    }
    
    private unowned let delegate: PodCommsSessionDelegate

    let session: CommandSession
    let device: RileyLinkDevice
    
    init(podState: PodState?, session: CommandSession, device: RileyLinkDevice, delegate: PodCommsSessionDelegate) {
        self.podState = podState
        self.session = session
        self.device = device
        self.delegate = delegate
    }
    
    func configureRadio() throws {
        print("************ configureRadio(Omnipod) ******************")

        //        SYNC1     |0xDF00|0x54|Sync Word, High Byte
        //        SYNC0     |0xDF01|0xC3|Sync Word, Low Byte
        //        PKTLEN    |0xDF02|0x32|Packet Length
        //        PKTCTRL1  |0xDF03|0x24|Packet Automation Control
        //        PKTCTRL0  |0xDF04|0x00|Packet Automation Control
        //        FSCTRL1   |0xDF07|0x06|Frequency Synthesizer Control
        //        FREQ2     |0xDF09|0x12|Frequency Control Word, High Byte
        //        FREQ1     |0xDF0A|0x14|Frequency Control Word, Middle Byte
        //        FREQ0     |0xDF0B|0x5F|Frequency Control Word, Low Byte
        //        MDMCFG4   |0xDF0C|0xCA|Modem configuration
        //        MDMCFG3   |0xDF0D|0xBC|Modem Configuration
        //        MDMCFG2   |0xDF0E|0x0A|Modem Configuration
        //        MDMCFG1   |0xDF0F|0x13|Modem Configuration
        //        MDMCFG0   |0xDF10|0x11|Modem Configuration
        //        MCSM0     |0xDF14|0x18|Main Radio Control State Machine Configuration
        //        FOCCFG    |0xDF15|0x17|Frequency Offset Compensation Configuration
        //        AGCCTRL1  |0xDF18|0x70|AGC Control
        //        FSCAL3    |0xDF1C|0xE9|Frequency Synthesizer Calibration
        //        FSCAL2    |0xDF1D|0x2A|Frequency Synthesizer Calibration
        //        FSCAL1    |0xDF1E|0x00|Frequency Synthesizer Calibration
        //        FSCAL0    |0xDF1F|0x1F|Frequency Synthesizer Calibration
        //        TEST1     |0xDF24|0x31|Various Test Settings
        //        TEST0     |0xDF25|0x09|Various Test Settings
        //        PA_TABLE0 |0xDF2E|0x60|PA Power Setting 0
        //        VERSION   |0xDF37|0x04|Chip ID[7:0]
        
        try session.setSoftwareEncoding(.manchester)
        try session.setPreamble(0x6665)
        try session.setBaseFrequency(Measurement(value: 433.91, unit: .megahertz))
        try session.updateRegister(.pktctrl1, value: 0x20)
        try session.updateRegister(.pktctrl0, value: 0x00)
        try session.updateRegister(.fsctrl1, value: 0x06)
        try session.updateRegister(.mdmcfg4, value: 0xCA)
        try session.updateRegister(.mdmcfg3, value: 0xBC)  // 0xBB for next lower bitrate
        try session.updateRegister(.mdmcfg2, value: 0x06)
        try session.updateRegister(.mdmcfg1, value: 0x70)
        try session.updateRegister(.mdmcfg0, value: 0x11)
        try session.updateRegister(.deviatn, value: 0x44)
        try session.updateRegister(.mcsm0, value: 0x18)
        try session.updateRegister(.foccfg, value: 0x17)
        try session.updateRegister(.fscal3, value: 0xE9)
        try session.updateRegister(.fscal2, value: 0x2A)
        try session.updateRegister(.fscal1, value: 0x00)
        try session.updateRegister(.fscal0, value: 0x1F)
        
        try session.updateRegister(.test1, value: 0x31)
        try session.updateRegister(.test0, value: 0x09)
        try session.updateRegister(.paTable0, value: 0x84)
        try session.updateRegister(.sync1, value: 0xA5)
        try session.updateRegister(.sync0, value: 0x5A)
    }
    

    func incrementPacketNumber(_ count: Int = 1) {
        packetNumber = (packetNumber + count) & 0b11111
    }
    
    func incrementMessageNumber(_ count: Int = 1) {
        messageNumber = (messageNumber + count) & 0b1111
    }
    
    func nonceValue() throws -> UInt32 {
        guard let podState = self.podState else {
            throw PodCommsError.noPairedPod
        }
        return podState.currentNonce
    }
    
    func advanceToNextNonce() throws {
        if podState == nil {
            throw PodCommsError.noPairedPod
        }
        podState!.advanceToNextNonce()
    }
    
    func makeAckPacket(packetAddress: UInt32? = nil, messageAddress: UInt32? = nil) -> Packet {
        let addr1 = packetAddress ?? podState?.address ?? defaultAddress
        let addr2 = messageAddress ?? podState?.address ?? defaultAddress
        return Packet(address: addr1, packetType: .ack, sequenceNum: packetNumber, data:Data(bigEndian: addr2))
    }
    
    func ackUntilQuiet(packetAddress: UInt32? = nil, messageAddress: UInt32? = nil) throws {
        
        let packetData = (makeAckPacket(packetAddress: packetAddress, messageAddress: messageAddress)).encoded()

        var quiet = false
        while !quiet {
            do {
                let _ = try session.sendAndListen(packetData, repeatCount: 5, timeout: TimeInterval(milliseconds: 600), retryCount: 0, preambleExtension: TimeInterval(milliseconds: 40))
            } catch RileyLinkDeviceError.responseTimeout {
                // Haven't heard anything in 300ms.  POD heard our ack.
                quiet = true
            }
        }
        incrementPacketNumber()
    }
    
    
    func exchangePackets(packet: Packet, repeatCount: Int = 0, packetResponseTimeout: TimeInterval = .milliseconds(165), exchangeTimeout:TimeInterval = .seconds(20), preambleExtension: TimeInterval = .milliseconds(127)) throws -> Packet {
        let packetData = packet.encoded()
        let radioRetryCount = 20
        
        let start = Date()
        
        while (-start.timeIntervalSinceNow < exchangeTimeout)  {
            do {
                let rfPacket = try session.sendAndListen(packetData, repeatCount: repeatCount, timeout: packetResponseTimeout, retryCount: radioRetryCount, preambleExtension: preambleExtension)
                
                let candidatePacket: Packet
                
                do {
                    candidatePacket = try Packet(rfPacket: rfPacket)
                } catch {
                    continue
                }
            
                guard candidatePacket.address == packet.address else {
                    continue
                }
                
                guard candidatePacket.sequenceNum == ((packetNumber + 1) & 0b11111) else {
                    continue
                }
                
                // Once we have verification that the POD heard us, we can increment our counters
                incrementPacketNumber(2)
                
                return candidatePacket
            } catch RileyLinkDeviceError.responseTimeout {
                continue
            }
        }
        
        throw PodCommsError.noResponse
    }

    func exchangeMessages<T: MessageBlock>(_ message: Message, packetAddressOverride: UInt32? = nil, ackAddressOverride: UInt32? = nil) throws -> T {
        let packetAddress = packetAddressOverride ?? podState?.address ?? defaultAddress

        do {
            let responsePacket = try { () throws -> Packet in
                var firstPacket = true
                print("Send to POD: \(message)")
                var dataRemaining = message.encoded()
                while true {
                    let packetType: PacketType = firstPacket ? .pdm : .con
                    let sendPacket = Packet(address: packetAddress, packetType: packetType, sequenceNum: self.packetNumber, data: dataRemaining)
                    dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)
                    firstPacket = false
                    let response = try self.exchangePackets(packet: sendPacket)
                    if dataRemaining.count == 0 {
                        return response
                    }
                }
            }()
        
            guard responsePacket.packetType != .ack else {
                incrementMessageNumber()
                throw PodCommsError.podAckedInsteadOfReturningResponse
            }
            
            // Assemble fragmented message from multiple packets
            let response =  try { () throws -> Message in
                var responseData = responsePacket.data
                while true {
                    do {
                        return try Message(encodedData: responseData)
                    } catch MessageError.notEnoughData {
                        let ackForCon = self.makeAckPacket(packetAddress: packetAddress, messageAddress: ackAddressOverride)
                        print("Sending ACK for CON")
                        let conPacket = try self.exchangePackets(packet: ackForCon, repeatCount: 3, preambleExtension:TimeInterval(milliseconds: 40))
                        
                        guard conPacket.packetType == .con else {
                            throw PodCommsError.unexpectedPacketType(packetType: conPacket.packetType)
                        }
                        responseData += conPacket.data
                    }
                }
            }()
        
            incrementMessageNumber(2)
            
            try ackUntilQuiet(packetAddress: packetAddress, messageAddress: ackAddressOverride)
            
            guard response.messageBlocks.count > 0 else {
                throw PodCommsError.emptyResponse
            }
            
            guard let responseMessageBlock = response.messageBlocks[0] as? T else {
                let responseType = response.messageBlocks[0].blockType
                
                if responseType == .errorResponse, let errorResponse = response.messageBlocks[0] as? ErrorResponse, errorResponse.errorReponseType == .badNonce {
                    print("Pod returned bad nonce error.  Resyncing...")
                    self.podState?.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: try nonceValue(), messageSequenceNum: message.sequenceNum)
                }
                print("Unexpected response: \(responseType), \(response.messageBlocks[0])")
                throw PodCommsError.unexpectedResponse(response: responseType)
            }

            print("POD Response: \(responseMessageBlock)")
            return responseMessageBlock
            
        } catch let error {
            print("Error during communication with POD: \(error)")
            throw error
        }
    }

    func sendCommand<T: MessageBlock>(_ command: MessageBlock) throws -> T {
        let messageAddress = podState?.address ?? defaultAddress
        let message = Message(address: messageAddress, messageBlocks: [command], sequenceNum: messageNumber)
        return try exchangeMessages(message)
    }

    public func setupNewPOD(timeZone: TimeZone) throws {
        
        // Create random address with 20 bits.  Can we use all 24 bits?
        let newAddress = 0x1f000000 | (arc4random() & 0x000fffff)
        
        // Assign Address
        let assignAddress = AssignAddressCommand(address: newAddress)
        let assignAddressMessage = Message(address: defaultAddress, messageBlocks: [assignAddress], sequenceNum: messageNumber)
        let config1: ConfigResponse = try exchangeMessages(assignAddressMessage, packetAddressOverride: defaultAddress, ackAddressOverride: newAddress)
        
        // Verify address is set
        let activationDate = Date()
        let dateComponents = ConfirmPairingCommand.dateComponents(date: activationDate, timeZone: timeZone)
        let confirmPairing = ConfirmPairingCommand(address: newAddress, dateComponents: dateComponents, lot: config1.lot, tid: config1.tid)
        let confirmPairingMessage = Message(address: defaultAddress, messageBlocks: [confirmPairing], sequenceNum: messageNumber)
        let config2: ConfigResponse = try exchangeMessages(confirmPairingMessage, packetAddressOverride: defaultAddress, ackAddressOverride: newAddress)

        guard config2.pairingState == .paired else {
            throw PodCommsError.invalidData
        }
        
        let newPodState = PodState(
            address: newAddress,
            activatedAt: activationDate,
            timeZone: timeZone,
            piVersion: String(describing: config2.piVersion),
            pmVersion: String(describing: config2.pmVersion),
            lot: config2.lot,
            tid: config2.tid
        )
        self.podState = newPodState

//        # Configure Alerts (#1)
//        2017-09-11T11:07:55.989336 ID1:1f08ced2 PTYPE:PDM SEQ:12 ID2:1f08ced2 B9:08 BLEN:12 MTYPE:190a BODY:c8a1e9874c0000c8010201b3 CRC:80
//        2017-09-11T11:07:56.064666 ID1:1f08ced2 PTYPE:POD SEQ:13 ID2:1f08ced2 B9:0c BLEN:10 MTYPE:1d03 BODY:00001000000003ff80e0 CRC:ce
//        2017-09-11T11:07:56.074172 ID1:1f08ced2 PTYPE:ACK SEQ:14 ID2:1f08ced2 CRC:7e
//
//        # Configure Alerts (#2)
//        2017-09-11T11:07:56.732676 ID1:1f08ced2 PTYPE:PDM SEQ:15 ID2:1f08ced2 B9:10 BLEN:12 MTYPE:190a BODY:e3955e6078370005080282e1 CRC:29
//        2017-09-11T11:07:56.808941 ID1:1f08ced2 PTYPE:POD SEQ:16 ID2:1f08ced2 B9:14 BLEN:10 MTYPE:1d03 BODY:00002000000003ff8171 CRC:5d
//        2017-09-11T11:07:56.825231 ID1:1f08ced2 PTYPE:ACK SEQ:17 ID2:1f08ced2 CRC:7c
        
        let cancel1 = ConfigureAlertsCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "4c0000c80102")!)
        let _: StatusResponse = try sendCommand(cancel1)
        try advanceToNextNonce()
        
        let cancel2 = ConfigureAlertsCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "783700050802")!)
        let _: StatusResponse = try sendCommand(cancel2)
        try advanceToNextNonce()
        
        // Mark 2.6U delivery for prime
        
        // 1a0e bed2e16b 02 010a 01 01a0 0034 0034 170d 00 0208 000186a0
        let primeUnits = 2.6
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: primeUnits, multiplier: 8)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: primeUnits, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let message = Message(address: newAddress, messageBlocks: [scheduleCommand, bolusExtraCommand], sequenceNum: messageNumber)
        let _: StatusResponse = try exchangeMessages(message)
        try advanceToNextNonce()
    }
    
    public func finishPrime() throws {
        // 19 0a 365deab7 38000ff00302 80b0
        let finishPrimeCommand = ConfigureAlertsCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "38000ff00302")!)
        let _: StatusResponse = try sendCommand(finishPrimeCommand)
        try advanceToNextNonce()
    }
    
    public func bolus(units: Double) throws {
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: units, multiplier: 16)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: bolusSchedule)
        
        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: units, byte2: 0, unknownSection: Data(hexadecimalString: "00030d40")!)
        let setBolusMessage = Message(address: podState.address, messageBlocks: [bolusScheduleCommand, bolusExtraCommand], sequenceNum: messageNumber)
        let _: StatusResponse = try exchangeMessages(setBolusMessage)
        try advanceToNextNonce()
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws {
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        let tempBasalCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), tempBasalRate: rate, duration: duration)
        let tempBasalExtraCommand = TempBasalExtraCommand(rate: rate, duration: duration, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let setTempBasalMessage = Message(address: podState.address, messageBlocks: [tempBasalCommand, tempBasalExtraCommand], sequenceNum: messageNumber)
        let _: StatusResponse = try exchangeMessages(setTempBasalMessage)
        try advanceToNextNonce()
    }
    
    public func cancelTempBasal() throws {
        
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: .tempBasal, soundType: .beeeeeep)
        
        let _: StatusResponse = try sendCommand(cancelDelivery)
        
        self.podState?.advanceToNextNonce()
    }
    
    public func testingCommands() throws {
        try setTempBasal(rate: 1.0, duration: .minutes(30), confidenceReminder: false, programReminderInterval: .minutes(0))
    }
    
    public func setBasalSchedule(schedule: BasalSchedule, scheduleOffset: TimeInterval, confidenceReminder: Bool, programReminderInterval: TimeInterval) throws {
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }

        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), basalSchedule: schedule, scheduleOffset: scheduleOffset)
        let basalExtraCommand = BasalScheduleExtraCommand.init(schedule: schedule, scheduleOffset: scheduleOffset, confidenceReminder: confidenceReminder, programReminderInterval: programReminderInterval)
        
        let setBasalMessage = Message(address: podState.address, messageBlocks: [basalScheduleCommand, basalExtraCommand], sequenceNum: messageNumber)
        let _: StatusResponse = try exchangeMessages(setBasalMessage)
        try advanceToNextNonce()
    }
    
    // TODO: Need to take schedule as parameter
    public func insertCannula(basalSchedule: BasalSchedule, scheduleOffset: TimeInterval) throws {
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        // Set basal schedule
        try setBasalSchedule(schedule: basalSchedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: .minutes(0))
        
        // Configure Alerts
        // 19 16 ba952b8b 79a4 10df 0502 280012830602020f00000202
        let configureAlertsCommand = ConfigureAlertsCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "79a410df0502280012830602020f00000202")!)
        do {
            let _: StatusResponse = try sendCommand(configureAlertsCommand)
        } catch PodCommsError.podAckedInsteadOfReturningResponse {
            print("pod acked?")
        }
        
        try advanceToNextNonce()

        // Insert Cannula
        // 1a0e7e30bf16020065010050000a000a
        let insertionBolusAmount = 0.5
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: insertionBolusAmount, multiplier: 8)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: bolusSchedule)

        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: insertionBolusAmount, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let setBolusMessage = Message(address: podState.address, messageBlocks: [bolusScheduleCommand, bolusExtraCommand], sequenceNum: messageNumber)
        let _: StatusResponse = try exchangeMessages(setBolusMessage)
        try advanceToNextNonce()
    }
    
    public func getStatus() throws -> StatusResponse {
        
        let cmd = GetStatusCommand()
        let response: StatusResponse = try sendCommand(cmd)
        return response
    }
    
    public func changePod() throws {
        
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        defer {
            self.podState = nil
        }

        let cancelDelivery = CancelDeliveryCommand(nonce: podState.currentNonce, deliveryType: .all, soundType: .beeeeeep)

        let _: StatusResponse = try sendCommand(cancelDelivery)
        self.podState?.advanceToNextNonce()

        // PDM at this point makes a few get status requests, for logs and other details, presumably.
        // We don't know what to do with them, so skip for now.

        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        let _: StatusResponse = try sendCommand(deactivatePod)
    }
}

