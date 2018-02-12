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
    case noResponse
    case badAddress
    case unexpectedSequence
    case unexpectedResponseType(responseType: MessageBlockType)
    case unknownResponseType(rawType: UInt8)
}


public class PodCommsSession {
    
    let podState: PodState
    let session: CommandSession
    
    init(podState: PodState, session: CommandSession) {
        self.podState = podState
        self.session = session
    }
    
    
    func sendCommandsAndGetResponse(_ commands: [MessageBlock]) throws -> Message {
        let msg = Message(address: podState.address, messageBlocks: commands, sequenceNum: podState.messageNumber)
        
        // TODO: breaking msgData up into multiple packets if needed
        let sendPacket = Packet(address: podState.address, packetType: .pdm, sequenceNum: podState.packetNumber, data: msg.encoded())
        
        let retryCount = 2
        let timeout = TimeInterval(milliseconds: 165)
        let packetData = sendPacket.encoded()
        
        guard let rfPacket = try session.sendAndListen(packetData, repeatCount: 0, timeout: timeout, retryCount: retryCount, preambleExtension: TimeInterval(milliseconds: 127)) else {
            throw PodCommsError.noResponse
        }
        
        guard let packet = Packet(rfPacket: rfPacket) else {
            throw PodCommsError.invalidData
        }
        
        guard packet.address == podState.address else {
            throw PodCommsError.badAddress
        }
        
        guard packet.sequenceNum == ((podState.packetNumber + 1) & 0b11111) else {
            throw PodCommsError.unexpectedSequence
        }
        
        // Once we have verification that the POD heard us, we can increment our counters
        podState.incrementMessageNumber()
        podState.incrementMessageNumber()
        podState.incrementPacketNumber()
        podState.incrementPacketNumber()
        
        // TODO: Assemble fragmented message from multiple packets
        let response = try Message(encodedData: packet.data)
        
        // Send ACK
        let ack = Packet(address: podState.address, packetType: .ack, sequenceNum: podState.packetNumber, data:Data(hexadecimalString:"00000000")!)
        
        try session.send(ack.encoded(), onChannel: 0, timeout: TimeInterval(0), repeatCount: 2, delayBetweenPackets: TimeInterval(milliseconds: 30), preambleExtension: TimeInterval(milliseconds: 20))
        
        return response
    }
    
    public func getStatus() throws -> StatusResponse {
        try configureRadio()
        let cmd = GetStatusCommand()
        let response = try sendCommandsAndGetResponse([cmd])

        guard response.messageBlocks.count > 0, let statusResponse = response.messageBlocks[0] as? StatusResponse else {
            throw PodCommsError.noResponse
        }
        return statusResponse
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
    }
}


public extension Sequence where Element == UInt8 {
    
    public func flippedBytes() -> [UInt8] {
        
        var output = [UInt8]()
        for byte in self {
            output.append(byte ^ 0xff)
        }
        return output
    }
}




