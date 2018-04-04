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
                let _ = try session.sendAndListen(packetData, repeatCount: 3, timeout: TimeInterval(milliseconds: 300), retryCount: 0, preambleExtension: TimeInterval(milliseconds: 40))
            } catch RileyLinkDeviceError.responseTimeout {
                // Haven't heard anything in 300ms.  POD heard our ack.
                quiet = true
            }
        }
        incrementPacketNumber()
    }
    
    func listenForPacket(address: UInt32, timeout: TimeInterval = TimeInterval(milliseconds: 165), retryCount: Int = 0) throws -> Packet {
        var attemptCount = 0
        
        while retryCount - attemptCount > 0 {
            attemptCount += 1
            
            guard let rfPacket = try session.listen(onChannel: 0, timeout: timeout) else {
                throw PodCommsError.noResponse
            }
            
            let candidatePacket: Packet
            
            do {
                candidatePacket = try Packet(rfPacket: rfPacket)
            } catch {
                continue
            }
            
            guard candidatePacket.address == address else {
                continue
            }
            
            guard candidatePacket.sequenceNum == ((packetNumber + 1) & 0b11111) else {
                continue
            }
            
            // Once we have verification that the POD heard us, we can increment our counters
            incrementPacketNumber(2)
            
            return candidatePacket
        }
        
        throw PodCommsError.noResponse
    }
    
    func listenForMessage<T: MessageBlock>(address: UInt32) throws -> T {
        
        // Assemble fragmented message from multiple packets
        let message =  try { () throws -> Message in
            var responseData = Data()
            while true {
                do {
                    return try Message(encodedData: responseData)
                } catch MessageError.notEnoughData {
                    let packet = try self.listenForPacket(address: address)
                    responseData += packet.data
                }
            }
            }()
        
        incrementMessageNumber()
        
        try ackUntilQuiet(packetAddress: address, messageAddress: address)
        
        guard message.messageBlocks.count > 0 else {
            throw PodCommsError.emptyResponse
        }
        
        guard let messageBlock = message.messageBlocks[0] as? T else {
            let messageType = message.messageBlocks[0].blockType
            
            if messageType == .errorResponse, let errorResponse = message.messageBlocks[0] as? ErrorResponse, errorResponse.errorReponseType == .badNonce {
                print("Pod returned bad nonce error.  Resyncing...")
                self.podState?.resyncNonce(syncWord: errorResponse.nonceSearchKey, sentNonce: try nonceValue(), messageSequenceNum: message.sequenceNum)
            }
            print("Unexpected response: \(messageType), \(message.messageBlocks[0])")
            throw PodCommsError.unexpectedResponse(response: messageType)
        }
        
        return messageBlock
    }

    
    func sendPacketAndGetResponse(packet: Packet, repeatCount: Int = 0, timeout: TimeInterval = TimeInterval(milliseconds: 165), retryCount: Int = 0, preambleExtention: TimeInterval = TimeInterval(milliseconds: 127)) throws -> Packet {
        let packetData = packet.encoded()
        var attemptCount = 0
        
        while retryCount - attemptCount > 0 {
            attemptCount += 1
            
            guard let rfPacket = try session.sendAndListen(packetData, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount-attemptCount, preambleExtension: preambleExtention) else {
                throw PodCommsError.noResponse
            }
            
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
        }
        
        throw PodCommsError.noResponse
    }

    func sendMessage<T: MessageBlock>(_ message: Message, packetAddressOverride: UInt32? = nil, ackAddressOverride: UInt32? = nil) throws -> T {
        let packetAddress = packetAddressOverride ?? podState?.address ?? defaultAddress

        
        let responsePacket = try { () throws -> Packet in
            var sentPacketsCount = 0
            var dataRemaining = message.encoded()
            while true {
                let packetType: PacketType = sentPacketsCount > 0 ? .con : .pdm
                let sendPacket = Packet(address: packetAddress, packetType: packetType, sequenceNum: self.packetNumber, data: dataRemaining)
                dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)
                if dataRemaining.count > 0 {
                    let podAck = try self.sendPacketAndGetResponse(packet: sendPacket, retryCount: 5)
                    print("Got podAck: \(podAck)")
                    sentPacketsCount += 1
                } else {
                    let response = try self.sendPacketAndGetResponse(packet: sendPacket, retryCount: 5)
                    sentPacketsCount += 1
                    print("Got response: \(response)")
                    return response
                }
            }
        }()
        
            
        // Assemble fragmented message from multiple packets
        let response =  try { () throws -> Message in
            var responseData = responsePacket.data
            while true {
                do {
                    return try Message(encodedData: responseData)
                } catch MessageError.notEnoughData {
                    let ackForCon = self.makeAckPacket(packetAddress: packetAddress, messageAddress: ackAddressOverride)
                    let conPacket = try self.sendPacketAndGetResponse(packet: ackForCon, repeatCount: 3, retryCount: 5, preambleExtention:TimeInterval(milliseconds: 40))
                    
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

        return responseMessageBlock
    }

    func sendCommand<T: MessageBlock>(_ command: MessageBlock) throws -> T {
        let messageAddress = podState?.address ?? defaultAddress
        let message = Message(address: messageAddress, messageBlocks: [command], sequenceNum: messageNumber)
        return try sendMessage(message)
    }
    

    public func setupNewPOD(timeZone: TimeZone) throws {
        
        // Create random address with 20 bits.  Can we use all 24 bits?
        let newAddress = 0x1f000000 | (arc4random() & 0x000fffff)
        
        // Assign Address
        let assignAddress = AssignAddressCommand(address: newAddress)
        let assignAddressMessage = Message(address: defaultAddress, messageBlocks: [assignAddress], sequenceNum: messageNumber)
        let config1: ConfigResponse = try sendMessage(assignAddressMessage, packetAddressOverride: defaultAddress, ackAddressOverride: newAddress)
        
        // Verify address is set
        let activationDate = Date()
        let dateComponents = ConfirmPairingCommand.dateComponents(date: activationDate, timeZone: timeZone)
        let confirmPairing = ConfirmPairingCommand(address: newAddress, dateComponents: dateComponents, lot: config1.lot, tid: config1.tid)
        let confirmPairingMessage = Message(address: defaultAddress, messageBlocks: [confirmPairing], sequenceNum: messageNumber)
        let config2: ConfigResponse = try sendMessage(confirmPairingMessage, packetAddressOverride: defaultAddress, ackAddressOverride: newAddress)

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

//        # Cancel Temp Delivery (#1)
//        2017-09-11T11:07:55.989336 ID1:1f08ced2 PTYPE:PDM SEQ:12 ID2:1f08ced2 B9:08 BLEN:12 MTYPE:190a BODY:c8a1e9874c0000c8010201b3 CRC:80
//        2017-09-11T11:07:56.064666 ID1:1f08ced2 PTYPE:POD SEQ:13 ID2:1f08ced2 B9:0c BLEN:10 MTYPE:1d03 BODY:00001000000003ff80e0 CRC:ce
//        2017-09-11T11:07:56.074172 ID1:1f08ced2 PTYPE:ACK SEQ:14 ID2:1f08ced2 CRC:7e
//
//        # Cancel Temp Delivery (#2)
//        2017-09-11T11:07:56.732676 ID1:1f08ced2 PTYPE:PDM SEQ:15 ID2:1f08ced2 B9:10 BLEN:12 MTYPE:190a BODY:e3955e6078370005080282e1 CRC:29
//        2017-09-11T11:07:56.808941 ID1:1f08ced2 PTYPE:POD SEQ:16 ID2:1f08ced2 B9:14 BLEN:10 MTYPE:1d03 BODY:00002000000003ff8171 CRC:5d
//        2017-09-11T11:07:56.825231 ID1:1f08ced2 PTYPE:ACK SEQ:17 ID2:1f08ced2 CRC:7c
        
        let cancel1 = CancelBasalCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "4c0000c80102")!)
        let cancel1Response: StatusResponse = try sendCommand(cancel1)
        print("cancel1Response = \(cancel1Response)")
        try advanceToNextNonce()
        
        let cancel2 = CancelBasalCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "783700050802")!)
        let cancel12Response: StatusResponse = try sendCommand(cancel2)
        print("cancel1Response = \(cancel12Response)")
        try advanceToNextNonce()
        
        // Mark 2.6U delivery for prime
        
        // 1a0e bed2e16b 02 010a 01 01a0 0034 0034 170d 00 0208 000186a0
        let primeUnits = 2.6
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: primeUnits, multiplier: 8)
        let scheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: bolusSchedule)
        let bolusExtraCommand = BolusExtraCommand(units: primeUnits, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let message = Message(address: newAddress, messageBlocks: [scheduleCommand, bolusExtraCommand], sequenceNum: messageNumber)
        let primeResponse: StatusResponse = try sendMessage(message)
        print("primeResponse = \(primeResponse)")
        try advanceToNextNonce()
    }
    
    public func finishPrime() throws {
        // 19 0a 365deab7 38000ff00302 80b0
        let finishPrimeCommand = CancelBasalCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "38000ff00302")!)
        let response: StatusResponse = try sendCommand(finishPrimeCommand)
        print("finish prime response = \(response)")
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
        let setBolusResponse: StatusResponse = try sendMessage(setBolusMessage)
        print("setBolusResponse = \(setBolusResponse)")
        try advanceToNextNonce()
    }

    
    public func testingCommands() throws {
        try bolus(units: 5.0)
    }
    
    // TODO: Need to take schedule as parameter
    public func insertCannula() throws {
        guard let podState = podState else {
            throw PodCommsError.noPairedPod
        }
        
        // Set basal schedule
        // Hardcoded 0.05 U/hr for 24 hours
        let scheduleEntry = SetInsulinScheduleCommand.BasalScheduleEntry(segments: 16, pulses: 0, alternateSegmentPulse: true)
        let deliverySchedule = SetInsulinScheduleCommand.DeliverySchedule.basalSchedule(currentSegment: 0x2b, secondsRemaining: 737, pulsesRemaining: 0, entries: [scheduleEntry, scheduleEntry, scheduleEntry])
        let basalScheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: deliverySchedule)
        let rateEntry = BasalScheduleExtraCommand.RateEntry(rate: 0.05, duration: TimeInterval(hours: 24))
        let basalExtraCommand = BasalScheduleExtraCommand.init(currentEntryIndex: 0, remainingPulses: 689, delayUntilNextPulse: TimeInterval(seconds: 20), rateEntries: [rateEntry])
        let setBasalMessage = Message(address: podState.address, messageBlocks: [basalScheduleCommand, basalExtraCommand], sequenceNum: messageNumber)
        let statusResponse: StatusResponse = try sendMessage(setBasalMessage)
        try advanceToNextNonce()
        print("statusResponse = \(statusResponse)")
        
        // Cancel basal
        // 19 16 ba952b8b 79a4 10df 0502 280012830602020f00000202
        let cancelBasalCommand = CancelBasalCommand(nonce: try nonceValue(), unknownSection: Data(hexadecimalString: "79a410df0502280012830602020f00000202")!)
        let cancelBasalResponse: StatusResponse = try sendCommand(cancelBasalCommand)
        print("cancelBasalResponse = \(cancelBasalResponse)")
        try advanceToNextNonce()

        // Insert Cannula
        // 1a0e7e30bf16020065010050000a000a
        let insertionBolusAmount = 0.5
        let bolusSchedule = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: insertionBolusAmount, multiplier: 8)
        let bolusScheduleCommand = SetInsulinScheduleCommand(nonce: try nonceValue(), deliverySchedule: bolusSchedule)

        // 17 0d 00 0064 0001 86a0000000000000
        let bolusExtraCommand = BolusExtraCommand(units: insertionBolusAmount, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        let setBolusMessage = Message(address: podState.address, messageBlocks: [bolusScheduleCommand, bolusExtraCommand], sequenceNum: messageNumber)
        let setBolusResponse: StatusResponse = try sendMessage(setBolusMessage)
        print("setBolusResponse = \(setBolusResponse)")
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

        let cancelBolus = CancelBolusCommand(nonce: podState.currentNonce)

        let cancelBolusResponse: StatusResponse = try sendCommand(cancelBolus)
        self.podState?.advanceToNextNonce()

        print("cancelBolusResponse = \(cancelBolusResponse)")

        // PDM at this point makes a few get status requests, for logs and other details, presumably.
        // We don't know what to do with them, so skip for now.

        let deactivatePod = DeactivatePodCommand(nonce: podState.currentNonce)
        let deactivationResponse: StatusResponse = try sendCommand(deactivatePod)
        print("deactivationResponse = \(deactivationResponse)")

        try ackUntilQuiet()

    }
}

