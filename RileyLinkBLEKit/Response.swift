//
//  Response.swift
//  RileyLinkBLEKit
//
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

enum ResponseCode: UInt8 {
    case rxTimeout          = 0xaa
    case commandInterrupted = 0xbb
    case zeroData           = 0xcc
    case success            = 0xdd
    case invalidParam       = 0x11
    case unknownCommand     = 0x22
}

protocol Response {
    var code: ResponseCode { get }

    init?(data: Data)

    init?(legacyData data: Data)
}

struct CodeResponse: Response {
    let code: ResponseCode

    init?(data: Data) {
        guard data.count == 1, let code = ResponseCode(rawValue: data[data.startIndex]) else {
            return nil
        }

        self.code = code
    }

    init?(legacyData data: Data) {
        guard data.count == 0 else {
            return nil
        }

        self.code = .success
    }
}

struct UpdateRegisterResponse: Response {
    let code: ResponseCode

    init?(data: Data) {
        guard data.count > 0, let code = ResponseCode(rawValue: data[data.startIndex]) else {
            return nil
        }

        self.code = code
    }

    private enum LegacyCode: UInt8 {
        case success = 1
        case invalidRegister = 2

        var responseCode: ResponseCode {
            switch self {
            case .success:
                return .success
            case .invalidRegister:
                return .invalidParam
            }
        }
    }

    init?(legacyData data: Data) {
        guard data.count > 0, let code = LegacyCode(rawValue: data[data.startIndex])?.responseCode else {
            return nil
        }

        self.code = code
    }
}

struct GetVersionResponse: Response {
    let code: ResponseCode
    let version: String

    init?(data: Data) {
        guard data.count > 0, let code = ResponseCode(rawValue: data[data.startIndex]) else {
            return nil
        }

        self.init(code: code, versionData: data[data.startIndex.advanced(by: 1)...])
    }

    init?(legacyData data: Data) {
        self.init(code: .success, versionData: data)
    }

    private init?(code: ResponseCode, versionData: Data) {
        self.code = code

        guard let version = String(bytes: versionData, encoding: .utf8) else {
            return nil
        }

        self.version = version
    }
}

struct GetStatisticsResponse: Response {
    let code: ResponseCode
    
    let uptime: TimeInterval
    let radioRxOverflowCount: UInt16
    let radioRxFifoOverflowCount: UInt16
    let packetRxCount: UInt16
    let packetTxCount: UInt16
    let crcFailureCount: UInt16
    let spiSyncFailureCount: UInt16

    init?(data: Data) {
        guard data.count > 0, let code = ResponseCode(rawValue: data[data.startIndex]) else {
            return nil
        }
        
        self.init(code: code, data: data[data.startIndex.advanced(by: 1)...])
    }
    
    init?(legacyData data: Data) {
        self.init(code: .success, data: data)
    }

    private init?(code: ResponseCode, data: Data) {
        self.code = code
        
        self.uptime = TimeInterval(milliseconds: Double(data[data.startIndex...].toBigEndian(UInt32.self)))
        self.radioRxOverflowCount = data[data.startIndex.advanced(by: 4)...].toBigEndian(UInt16.self)
        self.radioRxFifoOverflowCount = data[data.startIndex.advanced(by: 6)...].toBigEndian(UInt16.self)
        self.packetRxCount = data[data.startIndex.advanced(by: 8)...].toBigEndian(UInt16.self)
        self.packetTxCount = data[data.startIndex.advanced(by: 10)...].toBigEndian(UInt16.self)
        self.crcFailureCount = data[data.startIndex.advanced(by: 12)...].toBigEndian(UInt16.self)
        self.spiSyncFailureCount = data[data.startIndex.advanced(by: 14)...].toBigEndian(UInt16.self)
    }
}


struct PacketResponse: Response {
    let code: ResponseCode
    let packet: RFPacket?

    init?(data: Data) {
        guard data.count > 0, let code = ResponseCode(rawValue: data[data.startIndex]) else {
            return nil
        }

        switch code {
        case .success:
            guard let packet = RFPacket(rfspyResponse: data[data.startIndex.advanced(by: 1)...]) else {
                return nil
            }
            self.packet = packet
        case .rxTimeout,
             .commandInterrupted,
             .zeroData,
             .invalidParam,
             .unknownCommand:
            self.packet = nil
        }

        self.code = code
    }

    init?(legacyData data: Data) {
        guard data.count > 0 else {
            return nil
        }

        packet = RFPacket(rfspyResponse: data)

        if packet != nil {
            code = .success
        } else {
            guard let code = ResponseCode(rawValue: data[data.startIndex]) else {
                return nil
            }

            self.code = code
        }
    }

    init(code: ResponseCode, packet: RFPacket?) {
        self.code = code
        self.packet = packet
    }
}
