//
//  ConfigureAlertsCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ConfigureAlertsCommand : NonceResyncableMessageBlock {

    public enum ExpirationType {
        case reservoir(volume: Double)
        case time(TimeInterval)
    }

    public enum BeepRepeat: UInt8 {
        case once = 0
        case every1MinuteFor3MinutesAndRepeatEvery60Minutes = 1
        case every1MinuteFor15Minutes = 2
        case every1MinuteFor3MinutesAndRepeatEvery15Minutes = 3
        case every3MinutesFor60minutesStartingAt2Minutes = 4
        case every60Minutes = 5
        case every15Minutes = 6
        case every15MinutesFor60minutesStartingAt14Minutes = 7
        case every5Minutes = 8
    }
    
    public enum BeepType: UInt8 {
        case noBeep = 0
        case beepBeepBeepBeep = 1
        case bipBeepBipBeepBipBeepBipBeep = 2
        case bipBip = 3
        case beep = 4
        case beepBeepBeep = 5
        case beeeeeep = 6
        case bipBipBipbipBipBip = 7
        case beeepBeeep = 8
    } // Reused in CancelDeliveryCommand
    
    public struct AlertConfiguration {
        let alertType: Alert
        let expirationType: ExpirationType
        let audible: Bool
        let duration: TimeInterval
        let beepRepeat: BeepRepeat
        let beepType: BeepType
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
            data.append(beepRepeat.rawValue)
            data.append(beepType.rawValue)

            return data
        }
        
        public init(alertType: Alert, audible: Bool, autoOffModifier: Bool, duration: TimeInterval, expirationType: ExpirationType, beepRepeat: BeepRepeat, beepType: BeepType) {
            self.alertType = alertType
            self.audible = audible
            self.autoOffModifier = autoOffModifier
            self.duration = duration
            self.expirationType = expirationType
            self.beepRepeat = beepRepeat
            self.beepType = beepType
            
        }
        
        public init(encodedData: Data) throws {
            if encodedData.count < 6 {
                throw MessageBlockError.notEnoughData
            }
            
            let alertTypeBits = encodedData[0] >> 4
            guard let alertType = Alert(rawValue: alertTypeBits) else {
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
            
            let beepRepeatBits = encodedData[4]
            guard let beepRepeat = BeepRepeat(rawValue: beepRepeatBits) else {
                throw MessageError.unknownValue(value: beepRepeatBits, typeDescription: "BeepRepeat")
            }
            self.beepRepeat = beepRepeat
            
            let beepTypeBits = encodedData[5]
            guard let beepType = BeepType(rawValue: beepTypeBits) else {
                throw MessageError.unknownValue(value: beepTypeBits, typeDescription: "BeepType")
            }
            self.beepType = beepType
 
        }
    }
    
    public let blockType: MessageBlockType = .configureAlerts
    
    public var nonce: UInt32
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
