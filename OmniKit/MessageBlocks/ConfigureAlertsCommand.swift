//
//  ConfigureAlertsCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigureAlertsCommand : MessageBlock {
    
        // Pairing ConfigureAlerts #1
        // 4c00 0190 0102
        // 4c00 00c8 0102
        // 4c00 00c8 0102
        // 4c00 0096 0102
        // 4c00 0064 0102
    
        // Pairing ConfigureAlerts #2
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802
        // 7837 0005 0802

        // Pairing ConfigureAlerts #3
        // 3800 0ff0 0302
        // 3800 10a4 0302
        // 3800 10a4 0302
        // 3800 10a4 0302
        // 3800 0ff0 0302
    
    public enum AlertType: UInt8 {
        case autoOff            = 0x00
        case endOfService       = 0x02
        case expirationAdvisory = 0x03
        case lowReservoir       = 0x04
        case suspendInProgress  = 0x05
        case suspendEnded       = 0x06
        case timerLimit         = 0x07
    }
    
    public enum ExpirationType {
        case reservoir(volume: Double)
        case time(TimeInterval)
    }
    
    public struct AlertConfiguration {
        let alertType: AlertType
        let expirationType: ExpirationType
        let audible: Bool
        let duration: TimeInterval
        let beepType: UInt16
        let autoOffModifier: Bool
        
        static let length = 6
        
        public var data: Data {
            var firstByte = alertType.rawValue << 4
            firstByte += audible ? (1 << 3) : 0
            
            if case .reservoir = expirationType {
                firstByte += 1 << 2
            }
            if autoOffModifier {
                firstByte += 1 << 1
            }
            // High bit of duration
            firstByte += UInt8((Int(duration.minutes) >> 8) & 0x1)
            
            var data = Data([
                firstByte,
                UInt8(Int(duration.minutes) & 0xff)
                ])
            
            switch expirationType {
            case .reservoir(let volume):
                let ticks = UInt16(volume / podPulseSize / 2)
                data.appendBigEndian(ticks)
            case .time(let duration):
                let minutes = UInt16(duration.minutes)
                data.appendBigEndian(minutes)
            }
            data.appendBigEndian(beepType)
            
            return data
        }
        
        public init(alertType: AlertType, audible: Bool, autoOffModifier: Bool, duration: TimeInterval, expirationType: ExpirationType, beepType: UInt16) {
            self.alertType = alertType
            self.audible = audible
            self.autoOffModifier = autoOffModifier
            self.duration = duration
            self.expirationType = expirationType
            self.beepType = beepType
        }
        
        public init(encodedData: Data) throws {
            if encodedData.count < 6 {
                throw MessageBlockError.notEnoughData
            }
            
            let alertTypeBits = encodedData[0] >> 4
            guard let alertType = AlertType(rawValue: alertTypeBits) else {
                throw MessageError.unknownValue(value: alertTypeBits, typeDescription: "AlertType")
            }
            self.alertType = alertType
            
            self.audible = encodedData[0] & 0b1000 != 0

            self.autoOffModifier = encodedData[0] & 0b10 != 0

            self.duration = TimeInterval(minutes: Double((Int(encodedData[0] & 0b1) << 8) + Int(encodedData[1])))

            let yyyy = (Int(encodedData[2]) << 8) + (Int(encodedData[3])) & 0x3fff

            if encodedData[0] & 0b100 != 0 {
                let volume = Double(yyyy * 2) * podPulseSize
                self.expirationType = .reservoir(volume: volume)
            } else {
                self.expirationType = .time(TimeInterval(minutes: Double(yyyy)))
            }
            
            self.beepType = (UInt16(encodedData[4]) << 8) + UInt16(encodedData[5])
        }
    }
    
    public let blockType: MessageBlockType = .configureAlerts
    
    let nonce: UInt32
    let configurations: [AlertConfiguration]
    
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            UInt8(4 + configurations.count * AlertConfiguration.length),
            ])
        data.appendBigEndian(nonce)
        for config in configurations {
            data.append(contentsOf: config.data)
        }
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 10 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        
        let length = Int(encodedData[1])
        
        let numConfigs = (length - 4) / AlertConfiguration.length
        
        var configs = [AlertConfiguration]()
        
        for i in 0..<numConfigs {
            let offset = 2 + 4 + i * AlertConfiguration.length
            configs.append(try AlertConfiguration(encodedData: encodedData.subdata(in: offset..<(offset+6))))
        }
        self.configurations = configs
    }
    
    public init(nonce: UInt32, configurations: [AlertConfiguration]) {
        self.nonce = nonce
        self.configurations = configurations
    }
}
