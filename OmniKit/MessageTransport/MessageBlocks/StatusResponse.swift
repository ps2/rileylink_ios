//
//  StatusResponse.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/23/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct StatusResponse : MessageBlock {
    
    public enum DeliveryStatus: UInt8, CustomStringConvertible {
        case deliveryInterrupted = 0
        case normal = 1
        case tempBasalRunning = 2
        case priming = 4
        case bolusInProgress = 5
        case bolusAndTempBasal = 6
        
        public var bolusing: Bool {
            return self == .bolusInProgress || self == .bolusAndTempBasal
        }
        
        public var tempBasalRunning: Bool {
            return self == .tempBasalRunning || self == .bolusAndTempBasal
        }

        
        public var description: String {
            switch self {
            case .deliveryInterrupted:
                return LocalizedString("Interrupted", comment: "Delivery status when delivery is interrupted")
            case .normal:
                return LocalizedString("Normal", comment: "Delivery status when basal is running")
            case .tempBasalRunning:
                return LocalizedString("Temp basal running", comment: "Delivery status when temp basal is running")
            case .priming:
                return LocalizedString("Priming", comment: "Delivery status when pod is priming")
            case .bolusInProgress:
                return LocalizedString("Bolusing", comment: "Delivery status when bolusing")
            case .bolusAndTempBasal:
                return LocalizedString("Bolusing with temp basal", comment: "Delivery status when bolusing and temp basal is running")
            }
        }
    }
    
    public enum ReservoirStatus: UInt8, CustomStringConvertible {
        case initialized = 0
        case tankPowerActivated = 1
        case tankFillCompleted = 2
        case pairingSuccess = 3
        case priming = 4
        case readyForInjection = 5
        case injectionStarted = 6
        case injectionDone = 7
        case aboveFiftyUnits = 8
        case belowFiftyUnits = 9
        case oneNotUsedButin33 = 10
        case twoNotUsedButin33 = 11
        case threeNotUsedButin33 = 12
        case errorEventLoggedShuttingDown = 13
        case delayedPrime = 14 // Saw this after delaying prime for a day
        case inactive = 15 // ($1C Deactivate Pod or packet header mismatch)

        public var description: String {
            switch self {
            case .initialized:
                return LocalizedString("Initialized", comment: "Pod inititialized")
            case .tankPowerActivated:
                return LocalizedString("Tank power activated", comment: "Pod power to motor activated")
            case .tankFillCompleted:
                return LocalizedString("Tank fill completed", comment: "Pod tank fill completed")
            case .pairingSuccess:
                return LocalizedString("Paired", comment: "Pod status after pairing")
            case .priming:
                return LocalizedString("Priming", comment: "Pod status when priming")
            case .readyForInjection:
                return LocalizedString("Ready to insert cannula", comment: "Pod status when ready for cannula insertion")
            case .injectionStarted:
                return LocalizedString("Cannula inserting", comment: "Pod status when inserting cannula")
            case .injectionDone:
                return LocalizedString("Cannula inserted", comment: "Pod status when cannula insertion finished")
            case .aboveFiftyUnits:
                return LocalizedString("Normal", comment: "Pod status when running above fifty units")
            case .belowFiftyUnits:
                return LocalizedString("Below 50 units", comment: "Pod status when running below fifty units")
            case .oneNotUsedButin33:
                 return LocalizedString("oneNotUsedButin33", comment: "Pod status oneNotUsedButin33")
            case .twoNotUsedButin33:
                 return LocalizedString("twoNotUsedButin33", comment: "Pod status twoNotUsedButin33")
            case .threeNotUsedButin33:
                 return LocalizedString("threeNotUsedButin33", comment: "Pod status threeNotUsedButin33")
            case .errorEventLoggedShuttingDown:
                return LocalizedString("Error event logged, shutting down", comment: "Pod status error event logged shutting down")
            case .delayedPrime:
                return LocalizedString("Prime not completed", comment: "Pod status when prime has not completed")
            case .inactive:
                return LocalizedString("Deactivated", comment: "Pod status when pod has been deactivated")
            }
        }
    }
    
    public static var maximumReservoirReading: Double = 50.0
    
    public enum PodAlarm: UInt8 {
        case podExpired      = 0b10000000
        case suspendExpired  = 0b01000000
        case suspended       = 0b00100000
        case belowFiftyUnits = 0b00010000
        case oneHourExpiry   = 0b00001000
        case podDeactivated  = 0b00000100
        case unknownBit2     = 0b00000010
        case unknownBit1     = 0b00000001
        
        public typealias AllCases = [PodAlarm]
        
        static var allCases: AllCases {
            return (0..<8).map { PodAlarm(rawValue: 1<<$0)! }
        }
    }
    
    public struct PodAlarmState: RawRepresentable, Collection, CustomStringConvertible {
        
        public typealias RawValue = UInt8
        public typealias Index = Int

        public let startIndex: Int
        public let endIndex: Int
        
        private let elements: [PodAlarm]
        
        public var rawValue: UInt8 {
            return elements.reduce(0) { $0 & $1.rawValue }
        }

        public init(rawValue: UInt8) {
            self.elements = PodAlarm.allCases.filter { rawValue & $0.rawValue != 0 }
            self.startIndex = 0
            self.endIndex = self.elements.count
        }
        
        public subscript(index: Index) -> PodAlarm {
            return elements[index]
        }
        
        public func index(after i: Int) -> Int {
            return i+1
        }
        
        public var description: String {
            if elements.count == 0 {
                return LocalizedString("No alarms", comment: "Pod alarm state when no alarms are activated")
            } else {
                let alarmDescriptions = elements.map { String(describing: $0) }
                return alarmDescriptions.joined(separator: ", ")
            }
        }
        
    }

    public let blockType: MessageBlockType = .statusResponse
    public let length: UInt8 = 10
    public let deliveryStatus: DeliveryStatus
    public let reservoirStatus: ReservoirStatus
    public let timeActive: TimeInterval
    public let reservoirLevel: Double?
    public let insulin: Double
    public let insulinNotDelivered: Double
    public let podMessageCounter: UInt8
    public let alarms: PodAlarmState
    
    
    public let data: Data
    
    public init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }
        
        data = encodedData.prefix(upTo: Int(length))
        
        guard let deliveryStatus = DeliveryStatus(rawValue: encodedData[1] >> 4) else {
            throw MessageError.unknownValue(value: encodedData[1] >> 4, typeDescription: "DeliveryStatus")
        }
        self.deliveryStatus = deliveryStatus
        
        guard let reservoirStatus = ReservoirStatus(rawValue: encodedData[1] & 0xf) else {
            throw MessageError.unknownValue(value: encodedData[1] & 0xf, typeDescription: "ReservoirStatus")
        }
        self.reservoirStatus = reservoirStatus

        let minutes = ((Int(encodedData[7]) & 0x7f) << 6) + (Int(encodedData[8]) >> 2)
        self.timeActive = TimeInterval(minutes: Double(minutes))
        
        let highInsulinBits = Int(encodedData[2] & 0xf) << 9
        let midInsulinBits = Int(encodedData[3]) << 1
        let lowInsulinBits = Int(encodedData[4] >> 7)
        self.insulin = podPulseSize * Double(highInsulinBits | midInsulinBits | lowInsulinBits)
        
        self.podMessageCounter = (encodedData[4] >> 3) & 0xf
        
        self.insulinNotDelivered = podPulseSize * Double((Int(encodedData[4] & 0x3) << 8) | Int(encodedData[5]))

        self.alarms = PodAlarmState(rawValue: ((encodedData[6] & 0x7f) << 1) | (encodedData[7] >> 7))
        
        let resHighBits = Int(encodedData[8] & 0x03) << 6
        let resLowBits = Int(encodedData[9] >> 2)
        let reservoirValue = round((Double((resHighBits + resLowBits))*50)/255)
        if reservoirValue < StatusResponse.maximumReservoirReading {
            self.reservoirLevel = reservoirValue
        } else {
            self.reservoirLevel = nil
        }
    }
}
