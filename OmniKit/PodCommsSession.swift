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
    case unexpectedResponse(response: MessageBlockType, to: MessageBlockType)
    case unknownResponseType(rawType: UInt8)
}

fileprivate let RadioConfigurationName = "Omnipod433"

public protocol PodCommsSessionDelegate: class {
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState)
}

public class PodCommsSession {
    
    var packetNumber = 0
    var messageNumber = 0
    
    
    private var podState: PodState {
        didSet {
            delegate.podCommsSession(self, didChange: podState)
        }
    }
    
    private unowned let delegate: PodCommsSessionDelegate

    let session: CommandSession
    let device: RileyLinkDevice
    
    init(podState: PodState, session: CommandSession, device: RileyLinkDevice, delegate: PodCommsSessionDelegate) {
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
        
        device.setRadioConfigName(RadioConfigurationName)
    }
    

    func incrementPacketNumber() {
        packetNumber = (packetNumber + 1) & 0b11111
    }
    
    func incrementMessageNumber() {
        messageNumber = (messageNumber + 1) & 0b1111
    }
    
    func ackPacket(packetAddress: UInt32? = nil, messageAddress: UInt32? = nil) -> Packet {
        let addr1 = packetAddress ?? podState.address
        let addr2 = messageAddress ?? podState.address
        return Packet(address: addr1, packetType: .ack, sequenceNum: packetNumber, data:addr2.bigEndian)
    }
    
    func ackUntilQuiet(packetAddress: UInt32? = nil, messageAddress: UInt32? = nil) throws {
        let ack = ackPacket(packetAddress: packetAddress, messageAddress: messageAddress)
        let packetData = ack.encoded()

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
    
    func sendPacketAndGetResponse(packet: Packet, repeatCount: Int = 0, timeout: TimeInterval = TimeInterval(milliseconds: 165), retryCount: Int = 0) throws -> Packet {
        let packetData = packet.encoded()
        var attemptCount = 0
        
        while retryCount - attemptCount > 0 {
            attemptCount += 1
            
            guard let rfPacket = try session.sendAndListen(packetData, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount-attemptCount, preambleExtension: TimeInterval(milliseconds: 127)) else {
                throw PodCommsError.noResponse
            }
        
            let candidatePacket = try Packet(rfPacket: rfPacket)
        
            guard candidatePacket.address == packet.address else {
                continue
            }
            
            guard candidatePacket.sequenceNum == ((packetNumber + 1) & 0b11111) else {
                continue
            }
            
            // Once we have verification that the POD heard us, we can increment our counters
            incrementPacketNumber()
            incrementPacketNumber()
            
            return candidatePacket
        }
        
        throw PodCommsError.noResponse
    }

    func sendCommand<T: MessageBlock>(_ command: MessageBlock, withDest: UInt32? = nil) throws -> T {
        let dest = withDest ?? podState.address
        let msg = Message(address: dest, messageBlocks: [command], sequenceNum: messageNumber)
        
        // TODO: breaking msgData up into multiple packets if needed
        let sendPacket = Packet(address: dest, packetType: .pdm, sequenceNum: packetNumber, data: msg.encoded())
        
        let responsePacket = try sendPacketAndGetResponse(packet: sendPacket, retryCount: 5)
        
        // Assemble fragmented message from multiple packets
        let response =  try { () throws -> Message in
            var responseData = responsePacket.data
            while true {
                do {
                    return try Message(encodedData: responseData)
                } catch MessageError.notEnoughData {
                    let conPacket = try self.sendPacketAndGetResponse(packet: self.ackPacket(packetAddress: dest), retryCount: 5)
                    
                    guard conPacket.packetType == .con else {
                        throw PodCommsError.unexpectedPacketType(packetType: conPacket.packetType)
                    }
                    responseData += conPacket.data
                }
            }
        }()
        
        incrementMessageNumber()
        incrementMessageNumber()
        
        guard response.messageBlocks.count > 0 else {
            throw PodCommsError.emptyResponse
        }
        
        guard let responseMessageBlock = response.messageBlocks[0] as? T else {
            let responseType = response.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType, to: command.blockType)
        }

        return responseMessageBlock
    }
    
    public func setupNewPOD() throws {
        
        // PDM sometimes increments by more than one?
        let newAddress = podState.address + 1
        
        // Assign Address
        let assignAddress = AssignAddressCommand(address: newAddress)
        let config1: ConfigResponse = try sendCommand(assignAddress, withDest: 0xffffffff)
        
        try ackUntilQuiet(packetAddress: 0xffffffff, messageAddress: newAddress)
        
        podState = PodState(
            address: newAddress,
            nonceState: NonceState(lot: config1.lot, tid: config1.tid),
            isActive: false,
            timeZone: podState.timeZone)
        

        // Verify address is set
        let dateComponents = ConfirmPairingCommand.dateComponents(date: Date(), timeZone: podState.timeZone)
        let confirmPairing = ConfirmPairingCommand(address: newAddress, dateComponents: dateComponents, lot: config1.lot, tid: config1.tid)
        let config2: ConfigResponse = try sendCommand(confirmPairing, withDest: 0xffffffff)
    
        try ackUntilQuiet(packetAddress: 0xffffffff, messageAddress: newAddress)

        guard config2.pairingState == .paired else {
            throw PodCommsError.invalidData
        }
        
        podState = PodState(
            address: newAddress,
            nonceState: NonceState(lot: config1.lot, tid: config1.tid),
            isActive: true,
            timeZone: podState.timeZone)
    }
    
    public func setTime() throws {
        
    }
    
    public func getStatus() throws -> StatusResponse {
        
        let cmd = GetStatusCommand()
        let response: StatusResponse = try sendCommand(cmd)
        
        try ackUntilQuiet()

        return response
    }
    
    public func changePod() throws {
        let cancelBolus = CancelBolusCommand(nonce: podState.nonceState.currentNonce())

        let cancelBolusResponse: StatusResponse = try sendCommand(cancelBolus)
        
        print("cancelBolusResponse = \(cancelBolusResponse)")
        
        try ackUntilQuiet()
        
        podState.nonceState.advanceToNextNonce()
        
        // PDM at this point makes a few get status requests, for logs and other details, presumably.
        // We don't know what to do with them, so skip for now.
        
        let deactivatePod = DeactivatePodCommand(nonce: podState.nonceState.currentNonce())
        let deactivationResponse: StatusResponse = try sendCommand(deactivatePod)
        print("deactivationResponse = \(deactivationResponse)")
        
        try ackUntilQuiet()

        podState.nonceState.advanceToNextNonce()
    }
    
    
}


