//
//  PumpOpsCommunication.swift
//  RileyLink
//
//  Created by Jaim Zuber on 3/2/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkBLEKit

class PumpOpsCommunication {
    private static let standardPumpResponseWindow: UInt32 = 180
    private let expectedMaxBLELatencyMS = 1500
    
    let session: RileyLinkCmdSession
    
    init(session: RileyLinkCmdSession) {
        self.session = session
    }
    
    func sendAndListen(_ msg: PumpMessage, timeoutMS: UInt32 = standardPumpResponseWindow, repeatCount: UInt8 = 0, msBetweenPackets: UInt8 = 0, retryCount: UInt8 = 3) throws -> PumpMessage {
        let cmd = SendAndListenCmd()
        cmd.outgoingData = MinimedPacket(outgoingData: msg.txData).encodedData()
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
        
        guard let encodedData = cmd.receivedPacket?.data else {
            throw PumpCommsError.noResponse(during: "Sent \(msg)")
        }
        
        guard let packet = MinimedPacket(encodedData: encodedData) else {
            // Encoding or CRC error
            throw PumpCommsError.unknownResponse(rx: encodedData.hexadecimalString, during: "Sent \(msg)")
        }
        
        guard let message = PumpMessage(rxData: packet.data) else {
            // Unknown packet type or message type
            throw PumpCommsError.unknownResponse(rx: packet.data.hexadecimalString, during: "Sent \(msg)")
        }
        
        guard message.address == msg.address else {
            throw PumpCommsError.crosstalk(message, during: "Sent \(msg)")
        }
        
        return message
    }
}
