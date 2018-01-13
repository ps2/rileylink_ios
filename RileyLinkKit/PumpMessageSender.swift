//
//  PumpMessageSender.swift
//  RileyLink
//
//  Created by Jaim Zuber on 3/2/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkBLEKit

private let standardPumpResponseWindow: TimeInterval = .milliseconds(180)

protocol PumpMessageSender {
    func writeCommand(_ command: Command, timeout: TimeInterval) throws -> Data

    func updateRegister(_ address: CC111XRegister, value: UInt8) throws

    func setBaseFrequency(_ frequency: Measurement<UnitFrequency>) throws

    /// Sends a message to the pump, listening for message in reply
    ///
    /// - Parameters:
    ///   - message: The message to send
    ///   - repeatCount: The number of times to repeat the message before listening begins
    ///   - timeout: The length of time to listen for a pump response
    ///   - retryCount: The number of times to repeat the send & listen sequence
    /// - Returns: The message reply
    /// - Throws: An error describing a failure in the sending or receiving of a message:
    ///     - PumpOpsError.crosstalk
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.peripheralError
    ///     - PumpOpsError.unknownResponse
    func sendAndListen(_ message: PumpMessage, repeatCount: UInt8, timeout: TimeInterval, retryCount: UInt8) throws -> PumpMessage
}

extension PumpMessageSender {
    /// Sends a message to the pump, listening for message in reply
    ///
    /// - Parameters:
    ///   - message: The message to send
    ///   - timeout: The length of time to listen for a pump response
    ///   - retryCount: The number of times to repeat the send & listen sequence
    /// - Returns: The message reply
    /// - Throws: An error describing a failure in the sending or receiving of a message:
    ///     - PumpOpsError.crosstalk
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.peripheralError
    ///     - PumpOpsError.unknownResponse
    func sendAndListen(_ message: PumpMessage, timeout: TimeInterval = standardPumpResponseWindow, retryCount: UInt8 = 3) throws -> PumpMessage {
        return try sendAndListen(message, repeatCount: 0, timeout: timeout, retryCount: retryCount)
    }
}

extension PumpMessageSender {
    /// - Throws: PumpOpsError.peripheralError
    func send(_ msg: PumpMessage, repeatCount: UInt8 = 0) throws {
        let command = SendPacket(
            outgoing: MinimedPacket(outgoingData: msg.txData).encodedData(),
            sendChannel: 0,
            repeatCount: repeatCount,
            delayBetweenPacketsMS: 0
        )

        do {
            _ = try writeCommand(command, timeout: 0)
        } catch let error as LocalizedError {
            throw PumpOpsError.peripheralError(error)
        }
    }

    /// Sends a message to the pump, expecting a specific response body
    ///
    /// - Parameters:
    ///   - message: The message to send
    ///   - responseType: The expected response message type
    ///   - repeatCount: The number of times to repeat the message before listening begins
    ///   - timeout: The length of time to listen for a pump response
    ///   - retryCount: The number of times to repeat the send & listen sequence
    /// - Returns: The expected response message body
    /// - Throws:
    ///     - PumpOpsError.crosstalk
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.peripheralError
    ///     - PumpOpsError.unexpectedResponse
    ///     - PumpOpsError.unknownResponse
    func getResponse<T: MessageBody>(to message: PumpMessage, responseType: MessageType = .pumpAck, repeatCount: UInt8 = 0, timeout: TimeInterval = standardPumpResponseWindow, retryCount: UInt8 = 3) throws -> T {
        let response = try sendAndListen(message, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount)

        guard response.messageType == responseType, let body = response.messageBody as? T else {
            if let body = response.messageBody as? PumpErrorMessageBody {
                switch body.errorCode {
                case .known(let code):
                    throw PumpOpsError.pumpError(code)
                case .unknown(let code):
                    throw PumpOpsError.unknownPumpErrorCode(code)
                }
            } else {
                throw PumpOpsError.unexpectedResponse(response, from: message)
            }
        }
        return body
    }

    func sendAndListen(_ message: PumpMessage, repeatCount: UInt8, timeout: TimeInterval, retryCount: UInt8) throws -> PumpMessage {
        let rfPacket = try sendAndListenForPacket(message, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount)

        guard let packet = MinimedPacket(encodedData: rfPacket.data) else {
            // TODO: Change error to better reflect that this is an encoding or CRC error
            throw PumpOpsError.unknownResponse(rx: rfPacket.data.hexadecimalString, during: message)
        }

        guard let response = PumpMessage(rxData: packet.data) else {
            // Unknown packet type or message type
            throw PumpOpsError.unknownResponse(rx: packet.data.hexadecimalString, during: message)
        }

        guard response.address == response.address else {
            throw PumpOpsError.crosstalk(response, during: message)
        }

        return response
    }

    /// - Throws:
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.peripheralError
    func sendAndListenForPacket(_ message: PumpMessage, repeatCount: UInt8 = 0, timeout: TimeInterval = standardPumpResponseWindow, retryCount: UInt8 = 3) throws -> RFPacket {
        let command = SendAndListen(
            message: message,
            repeatCount: repeatCount,
            timeout: timeout,
            retryCount: retryCount
        )

        guard let rfPacket = try writeCommandExpectingPacket(command, timeout: command.totalTimeout) else {
            throw PumpOpsError.noResponse(during: message)
        }

        return rfPacket
    }

    /// - Throws: PumpOpsError.peripheralError
    func writeCommandExpectingPacket(_ command: Command, timeout: TimeInterval) throws -> RFPacket? {
        let response: Data

        do {
            response = try writeCommand(command, timeout: timeout)
        } catch let error as LocalizedError {
            throw PumpOpsError.peripheralError(error)
        }

        return RFPacket(rfspyResponse: response)

        // TODO: Record general RSSI values?
    }
}
