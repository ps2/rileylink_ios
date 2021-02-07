//
//  VersionResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

fileprivate let assignAddressVersionLength: UInt8 = 0x15
fileprivate let setupPodVersionLength: UInt8 = 0x1B

public struct VersionResponse : MessageBlock {
    
    public struct FirmwareVersion : CustomStringConvertible {
        let major: UInt8
        let minor: UInt8
        let patch: UInt8
        
        public init(encodedData: Data) {
            major = encodedData[0]
            minor = encodedData[1]
            patch = encodedData[2]
        }
        
        public var description: String {
            return "\(major).\(minor).\(patch)"
        }
    }
    
    public let blockType: MessageBlockType = .versionResponse

    public let pmVersion: FirmwareVersion
    public let piVersion: FirmwareVersion
    public let podProgressStatus: PodProgressStatus
    public let lot: UInt32
    public let tid: UInt32
    public let address: UInt32
    public let productID: UInt8                     // always 2 (for PM = PI = 2.7.0), 2nd gen Omnipod?

    // These values only included in the shorter 0x15 VersionResponse for the AssignAddress command.
    public let gain: UInt8?                         // 2-bit value, max gain is at 0, min gain is at 2
    public let rssi: UInt8?                         // 6-bit value, max rssi seen 61

    // These values only included in the longer 0x1B VersionResponse for the SetupPod command.
    public let pulseSize: Double?                   // MUTP / 100,000, must be 0x1388 / 100,000 = 0.05U
    public let secondsPerBolusPulse: Double?        // EB / 8, nominally 0x10 / 8 = 2
    public let secondsPerPrimePulse: Double?        // EP / 8, nominally 0x08 / 8 = 1
    public let primeUnits: Double?                  // PB * pulseSize, nominally 0x34 * 0.05U = 2.6U
    public let cannulaInsertionUnits: Double?       // CB * pulseSize, nominally 0x0A * 0.05U = 0.5U
    public let serviceDuration: TimeInterval?       // PL hours, nominally 0x50 = 80 hours

    public let data: Data
    
    public init(encodedData: Data) throws {
        let responseLength = encodedData[1]
        data = encodedData.subdata(in: 0..<Int(responseLength + 2))

        switch responseLength {
        case assignAddressVersionLength:
            // This is the shorter 0x15 response for the 07 AssignAddress command.
            // 01 15 020700 020700 02 02 0000a377 0003ab37 9f 1f00ee87
            // 0  1  2      5      8  9  10       14       18 19
            // 01 LL MXMYMZ IXIYIZ ID 0J LLLLLLLL TTTTTTTT GS IIIIIIII
            //
            // LL = 0x15 (assignAddressVersionLength)
            // PM = MX.MY.MZ
            // PI = IX.IY.IZ
            // ID = Product ID (should always be 02)
            // 0J = Pod progress state (typically 02, could be 01)
            // LLLLLLLL = Lot
            // TTTTTTTT = Tid
            // GS = ggssssss (Gain/RSSI)
            // IIIIIIII = connection ID address

            pmVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 2..<5))
            piVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 5..<8))
            productID = encodedData[8]
            guard let progressStatus = PodProgressStatus(rawValue: encodedData[9]) else {
                throw MessageBlockError.parseError
            }
            podProgressStatus = progressStatus
            lot = encodedData[10...].toBigEndian(UInt32.self)
            tid = encodedData[14...].toBigEndian(UInt32.self)
            gain = (encodedData[18] & 0xc0) >> 6
            rssi = encodedData[18] & 0x3f
            address = encodedData[19...].toBigEndian(UInt32.self)
            
            // These values only included in the longer 0x1B VersionResponse for the 03 SetupPod command.
            pulseSize = nil
            secondsPerBolusPulse = nil
            secondsPerPrimePulse = nil
            primeUnits = nil
            cannulaInsertionUnits = nil
            serviceDuration = nil

        case setupPodVersionLength:
            // This is the longer 0x1B response for the 03 SetupPod command.
            // 01 1b 1388 10 08 34 0a 50 020700 020700 02 03 0000a62b 00044794 1f00ee87
            // 0  1  2    4  5  6  7  8  9      12     15 16 17       21       25
            // 01 LL MUTP EB EP PP CP PL MXMYMZ IXIYIZ ID 0J LLLLLLLL TTTTTTTT IIIIIIII
            //
            // LL = 0x1B (setupPodVersionMessageLength)
            // MUTP = 0x1388 = 5000, # of micro Units of U100 insulin per tenth of pulse
            // EB = 0x10 = 16, # of eighth secs per bolus pulse timing (2 seconds)
            // EP = 0x08, # of eighth secs per pulse time for priming boluses (1 second)
            // PP = 0x34 = 52, # of Prime Pulses (52 pulses x 0.05U/pulse = 2.6U)
            // CP = 0x0A = 10, # of Cannula insertion Pulses (10 pulses x 0.05U/pulse = 0.5U)
            // PL = 0x50 = 80, # of hours maximum Pod Life
            // PM = MX.MY.MZ
            // PI = IX.IY.IZ
            // ID = Product ID (should always be 02)
            // 0J = Pod progress state (should always be 03)
            // LLLLLLLL = Lot
            // TTTTTTTT = Tid
            // IIIIIIII = connection ID address

            pmVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 9..<12))
            piVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 12..<15))
            productID = encodedData[15]
            guard let progressStatus = PodProgressStatus(rawValue: encodedData[16]) else {
                throw MessageBlockError.parseError
            }
            podProgressStatus = progressStatus
            lot = encodedData[17...].toBigEndian(UInt32.self)
            tid = encodedData[21...].toBigEndian(UInt32.self)
            address = encodedData[25...].toBigEndian(UInt32.self)

            // Verify that the pulseSize matches our expected value as the basic validity check as per PDM.
            pulseSize = Double(encodedData[2...].toBigEndian(UInt16.self)) / 100000
            guard pulseSize == Pod.pulseSize else {
                throw MessageError.validationFailed(description: "pulseSize")
            }

            // These values will be verified &/or used in the pairing code.
            secondsPerBolusPulse = Double(encodedData[4]) / 8
            secondsPerPrimePulse = Double(encodedData[5]) / 8
            primeUnits = Double(encodedData[6]) * Pod.pulseSize
            cannulaInsertionUnits = Double(encodedData[7]) * Pod.pulseSize
            serviceDuration = TimeInterval.hours(Double(encodedData[8]))

            // These values only included in the shorter 0x15 VersionResponse for the AssignAddress command.
            gain = nil
            rssi = nil

        default:
            throw MessageBlockError.parseError
        }
    }

    public var isAssignAddressVersionResponse: Bool {
        return self.data.count == assignAddressVersionLength + 2
    }

    public var isSetupPodVersionResponse: Bool {
        return self.data.count == setupPodVersionLength + 2
    }
}

extension VersionResponse: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "VersionResponse(lot:\(lot), tid:\(tid), gain:\(gain?.description ?? "NA"), rssi:\(rssi?.description ?? "NA") address:\(Data(bigEndian: address).hexadecimalString), podProgressStatus:\(podProgressStatus), pmVersion:\(pmVersion), piVersion:\(piVersion))"
    }
}

