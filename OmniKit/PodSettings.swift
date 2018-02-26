//
//  PodSettings.swift
//  OmniKit
//
//  Created by Pete Schwamb on 2/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PodSettingsDelegate: class {
    func podSettingsChanged(_ podSettings: PodSettings)
}

public class PodSettings: RawRepresentable {
    public typealias RawValue = [String: Any]
    
    public var podAddress: UInt32 {
        didSet {
            delegate?.podSettingsChanged(self)
        }
    }
    
    public var timeZone: TimeZone {
        didSet {
            delegate?.podSettingsChanged(self)
        }
    }
    
    public var delegate: PodSettingsDelegate?

    public required init?(rawValue: RawValue) {
        guard
            let podAddress = rawValue["podAddress"] as? UInt32,
            let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds)
            else {
                return nil
            }

        self.podAddress = podAddress
        self.timeZone = timeZone
    }
    
    public init(podAddress: UInt32? = nil) {
        self.podAddress = podAddress ?? 0x1f000000 | twentyBitsOfRandomness()
        self.timeZone = .currentFixed
    }
    
    public var rawValue: RawValue {
        return [
            "podAddress": podAddress,
            "timeZone": timeZone.secondsFromGMT()
        ]
    }
    
    public func incrementAddress() {
        // It seems that sometimes the PDM assigned address jumps by more than one,
        // but not sure it's for any important reason.
        self.podAddress += 1
    }
}

fileprivate func twentyBitsOfRandomness() -> UInt32 {
    return arc4random() & 0x000fffff
}
