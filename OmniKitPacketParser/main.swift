//
//  main.swift
//  OmniKitPacketParser
//
//  Created by Pete Schwamb on 12/19/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

let printRepeats = true

enum ParsingError: Error {
    case invalidPacketType(str: String)
}

extension PacketType {
    init(rtlomniString: String) throws {
        switch rtlomniString {
        case "PTYPE:POD":
            self = .pod
        case "PTYPE:PDM":
            self = .pdm
        case "PTYPE:CON":
            self = .con
        case "PTYPE:ACK":
            self = .ack
        default:
            throw ParsingError.invalidPacketType(str: rtlomniString)
        }
    }
}

extension String {
    func valPart() -> String {
        return String(split(separator: ":")[1])
    }
}

extension Int {
    func nextPacketNumber(_ increment: Int) -> Int {
        return (self + increment) & 0b11111
    }
}

for filename in CommandLine.arguments[1...] {
    do {
        let data = try String(contentsOfFile: filename, encoding: .utf8)
        let lines = data.components(separatedBy: .newlines)
        
        // 1f00ee84 30 0a 1d18003f1800004297ff 8128
        var messageDate: String = ""
        var lastMessageData = Data()
        var lastPacket: ArraySlice<String>? = nil
        var messageData = Data()
        var messageSource: PacketType = .pdm
        var address: String = ""
        var packetNumber: Int = 0
        var repeatCount: Int = 0

        for line in lines {
            let components = line.components(separatedBy: .whitespaces)
            if components.count > 3, let packetType = try? PacketType(rtlomniString: components[2]) {
                if lastPacket == components[1...] {
                    continue
                }
                lastPacket = components[1...]
                switch packetType {
                case .pod, .pdm:
                    if components.count != 9 {
                        print("Invalid line:\(line)")
                        continue
                    }
                    // 2018-12-19T20:50:48.3d ID1:1f0b3557 PTYPE:POD SEQ:31 ID2:1f0b3557 B9:00 BLEN:205 BODY:02cb510032602138800120478004213c80092045800c203980 CRC:a8
                    messageDate = components[0]
                    messageSource = packetType
                    address = String(components[1].valPart())
                    packetNumber = Int(components[3].valPart())!
                    let messageAddress = String(components[4].valPart())
                    let b9 = String(components[5].valPart())
                    if messageData.count > 0 {
                        print("Dropping incomplete message data: \(messageData.hexadecimalString)")
                    }
                    messageData = Data(hexadecimalString: messageAddress + b9)!
                    let messageLen = UInt8(components[6].valPart())!
                    messageData.append(messageLen)
                    let packetData = Data(hexadecimalString: components[7].valPart())!
                    messageData.append(packetData)
                case .con:
                    // 2018-12-19T05:19:04.3d ID1:1f0b3557 PTYPE:CON SEQ:12 CON:0000000000000126 CRC:60
                    let packetAddress = String(components[1].valPart())
                    let nextPacketNumber = Int(components[3].valPart())!
                    if (packetAddress == address) && (nextPacketNumber == packetNumber.nextPacketNumber(2)) {
                        packetNumber = nextPacketNumber
                        let packetData = Data(hexadecimalString: components[4].valPart())!
                        messageData.append(packetData)
                    } else if packetAddress != address {
                        print("mismatched address: \(line)")
                    } else if nextPacketNumber != packetNumber.nextPacketNumber(2) {
                        print("mismatched packet number: \(nextPacketNumber) != \(packetNumber.nextPacketNumber(2)) \(line)")
                    }
                default:
                    break
                }
                do {
                    let message = try Message(encodedData: messageData)
                    let messageStr = "\(messageDate) \(messageSource) \(message)"
                    if lastMessageData == messageData {
                        repeatCount += 1
                        if printRepeats {
                            print(messageStr + " repeat:\(repeatCount)")
                        }
                    } else {
                        lastMessageData = messageData
                        repeatCount = 0
                        print(messageStr)
                    }
                    messageData = Data()
                } catch MessageError.notEnoughData {
                    continue
                } catch let error {
                    print("Error decoding message: \(error)")
                }
            }
        }
    } catch let error {
        print("Error: \(error)")
    }
}

