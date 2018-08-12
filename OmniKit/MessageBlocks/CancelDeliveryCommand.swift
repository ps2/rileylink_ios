//
//  CancelDeliveryCommand.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct CancelDeliveryCommand : MessageBlock {
    
    public let blockType: MessageBlockType = .cancelDelivery
    
    public struct DeliveryType: OptionSet {
        public let rawValue: UInt8
        
        static let basal     = DeliveryType(rawValue: 1 << 0)
        static let tempBasal = DeliveryType(rawValue: 1 << 1)
        static let bolus     = DeliveryType(rawValue: 1 << 2)
        
        static let all: DeliveryType = [.basal, .tempBasal, .bolus]
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    public struct SoundType: OptionSet {
        public let rawValue: UInt8
        
        static let noSound = SoundType(rawValue: 0)
        static let beepBeepBeepBeep = SoundType(rawValue: 1)
        static let bipBeepBipBeepBipBeepBipBeep = SoundType(rawValue: 2)
        static let bipBip = SoundType(rawValue: 3)
        static let beep = SoundType(rawValue: 4)
        static let beepBeepBeep = SoundType(rawValue: 5)
        static let beeeeeep = SoundType(rawValue: 6)
        static let bipBipBipbipBipBip = SoundType(rawValue: 7)
        static let beeepBeeep = SoundType(rawValue: 8)

        static let all: SoundType = [
            .noSound,
            .beepBeepBeepBeep,
            .bipBeepBipBeepBipBeepBipBeep,
            .bipBip,
            .beep,
            .beepBeepBeep,
            .beeeeeep,
            .bipBipBipbipBipBip,
            .beeepBeeep
        ]
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
    
    // ID1:1f00ee84 PTYPE:PDM SEQ:26 ID2:1f00ee84 B9:ac BLEN:7 MTYPE:1f05 BODY:e1f78752078196 CRC:03
    
    // Cancel bolus
    // 1f 05 be1b741a 64 - 1U
    // 1f 05 a00a1a95 64 - 1U over 1hr
    // 1f 05 ff52f6c8 64 - 1U immediate, 1U over 1hr
    
    // Cancel temp basal
    // 1f 05 f76d34c4 62 - 30U/hr
    // 1f 05 156b93e8 62 - ?
    // 1f 05 62723698 62 - 0%
    // 1f 05 2933db73 62 - 03ea
    
    // Suspend is a Cancel delivery, followed by a configure alerts command (0x19)
    // 1f 05 50f02312 03 191050f02312580f000f06046800001e0302
    
    // Deactivate pod:
    // 1f 05 e1f78752 07
    
    public let deliveryType: DeliveryType
    
    public let soundType: SoundType
    
    let nonce: UInt32
    
    public var data: Data {
        var data = Data(bytes: [
            blockType.rawValue,
            5,
            ])
        data.appendBigEndian(nonce)
        data.append((soundType.rawValue << 4) + deliveryType.rawValue)
        return data
    }
    
    public init(encodedData: Data) throws {
        if encodedData.count < 7 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        self.deliveryType = DeliveryType(rawValue: encodedData[6] & 0xf)
        self.soundType = SoundType(rawValue: encodedData[6] >> 4)
    }
    
    public init(nonce: UInt32, deliveryType: DeliveryType, soundType: SoundType) {
        self.nonce = nonce
        self.deliveryType = deliveryType
        self.soundType = soundType
    }
}
