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
    case badAddress
    case unexpectedSequence
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
        
        //        # ---------------------------------------------------
        //        # Packet sniffer settings for CC1110
        //        # ---------------------------------------------------
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
        
        guard let rfPacket = try session.sendAndListen(packetData, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount, preambleExtension: TimeInterval(milliseconds: 127)) else {
            throw PodCommsError.noResponse
        }
        
        let responsePacket = try Packet(rfPacket: rfPacket)
        
        guard responsePacket.address == packet.address else {
            throw PodCommsError.badAddress
        }
        
        guard responsePacket.sequenceNum == ((packetNumber + 1) & 0b11111) else {
            throw PodCommsError.unexpectedSequence
        }
        
        // Once we have verification that the POD heard us, we can increment our counters
        incrementPacketNumber()
        incrementPacketNumber()
        
        return responsePacket
    }

    func sendCommandsAndGetResponse(_ commands: [MessageBlock], toDest: UInt32? = nil) throws -> Message {
        let dest = toDest ?? podState.address
        let msg = Message(address: dest, messageBlocks: commands, sequenceNum: messageNumber)
        
        // TODO: breaking msgData up into multiple packets if needed
        let sendPacket = Packet(address: dest, packetType: .pdm, sequenceNum: packetNumber, data: msg.encoded())
        
        let responsePacket = try sendPacketAndGetResponse(packet: sendPacket, retryCount: 3)
        
        // Assemble fragmented message from multiple packets
        let response =  try { () throws -> Message in
            var responseData = responsePacket.data
            while true {
                do {
                    return try Message(encodedData: responseData)
                } catch MessageError.notEnoughData {
                    let conPacket = try self.sendPacketAndGetResponse(packet: self.ackPacket(packetAddress: dest), retryCount: 3)
                    
                    guard conPacket.packetType == .con else {
                        throw PodCommsError.unexpectedPacketType(packetType: conPacket.packetType)
                    }
                    responseData += conPacket.data
                }
            }
        }()
        
        incrementMessageNumber()
        incrementMessageNumber()
        
        return response
    }
    
    public func setupNewPOD() throws {
        
        // PDM sometimes increments by more than one?
        let newAddress = podState.address + 1
        let assignAddressCommand = AssignAddressCommand(address: newAddress)
        let assignAddressCommandResponse = try sendCommandsAndGetResponse([assignAddressCommand], toDest: 0xffffffff)
        
        // Send ACK
        try ackUntilQuiet(packetAddress: 0xffffffff, messageAddress: newAddress)

        guard assignAddressCommandResponse.messageBlocks.count > 0 else {
            throw PodCommsError.emptyResponse
        }

        guard let config1 = assignAddressCommandResponse.messageBlocks[0] as? ConfigResponse else {
            let responseType = assignAddressCommandResponse.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType, to: assignAddressCommand.blockType)
        }
        
        podState = PodState(
            address: newAddress,
            nonceState: NonceState(lot: config1.lot, tid: config1.tid),
            isActive: false,
            timeZone: podState.timeZone)
        
        let dateComponents = ConfirmPairingCommand.dateComponents(date: Date(), timeZone: podState.timeZone)
        let setPodTimeCommand = ConfirmPairingCommand(address: newAddress, dateComponents: dateComponents, lot: config1.lot, tid: config1.tid)
        let setPodTimeCommandResponse = try sendCommandsAndGetResponse([setPodTimeCommand], toDest: 0xffffffff)
        
        try ackUntilQuiet(packetAddress: 0xffffffff, messageAddress: newAddress)

        
        guard setPodTimeCommandResponse.messageBlocks.count > 0 else {
            throw PodCommsError.emptyResponse
        }
        
        guard let config2 = setPodTimeCommandResponse.messageBlocks[0] as? ConfigResponse else {
            let responseType = setPodTimeCommandResponse.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType, to: setPodTimeCommand.blockType)
        }

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
        let response = try sendCommandsAndGetResponse([cmd])
        
        try ackUntilQuiet()

        guard response.messageBlocks.count > 0 else {
            throw PodCommsError.emptyResponse
        }

        guard let statusResponse = response.messageBlocks[0] as? StatusResponse else {
            throw PodCommsError.unexpectedResponse(response: response.messageBlocks[0].blockType, to: cmd.blockType)
        }
        return statusResponse
    }
    
    public func changePod() throws {
        // TODO: actually stop pod
        self.podState = PodState(address: podState.address, nonceState: podState.nonceState, isActive: false, timeZone: podState.timeZone)
    }
    
    
}


