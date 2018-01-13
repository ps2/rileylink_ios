//
//  SendAndListen.swift
//  RileyLinkKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import MinimedKit
import RileyLinkBLEKit


extension SendAndListen {
    static let standardPumpResponseWindow: TimeInterval = .milliseconds(180)

    init(message: PumpMessage, repeatCount: UInt8, delayBetweenPackets: TimeInterval = 0, timeout: TimeInterval, retryCount: UInt8) {
        self.init(
            outgoing: MinimedPacket(outgoingData: message.txData).encodedData(),
            sendChannel: 0,
            repeatCount: repeatCount,
            delayBetweenPacketsMS: UInt8(clamping: Int(delayBetweenPackets.milliseconds)),
            listenChannel: 0,
            timeoutMS: UInt32(clamping: Int(timeout.milliseconds)),
            retryCount: retryCount
        )
    }

    private var delayBetweenPackets: TimeInterval {
        return .milliseconds(Double(delayBetweenPacketsMS))
    }

    private var timeout: TimeInterval {
        return .milliseconds(Double(timeoutMS))
    }

    var totalTimeout: TimeInterval {
        // At least 12 ms between packets for radio to stop/start
        let minTimeBetweenPackets: TimeInterval = .milliseconds(12)
        let timeBetweenPackets = max(minTimeBetweenPackets, delayBetweenPackets)

        // 16384 = bitrate, 8 = bits per byte
        let singlePacketSendTime: TimeInterval = (Double(outgoing.count * 8) / 16_384)
        let totalRepeatSendTime: TimeInterval = (singlePacketSendTime + timeBetweenPackets) * Double(repeatCount)
        return (totalRepeatSendTime + timeout) * Double(retryCount + 1)
    }
}
