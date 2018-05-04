//
//  UserDefaults.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkKit


extension UserDefaults {
    private enum Key: String {
        case pumpSettings = "com.rileylink.pumpSettings"
        case pumpState = "com.rileylink.pumpState"
    }

    var pumpSettings: PumpSettings? {
        get {
            guard let raw = dictionary(forKey: Key.pumpSettings.rawValue) else {
                return nil
            }

            return PumpSettings(rawValue: raw)
        }
        set {
            set(newValue?.rawValue
                , forKey: Key.pumpSettings.rawValue)
        }
    }

    var pumpState: PumpState? {
        get {
            guard let raw = dictionary(forKey: Key.pumpState.rawValue) else {
                return nil
            }

            return PumpState(rawValue: raw)
        }
        set {
            set(newValue?.rawValue, forKey: Key.pumpState.rawValue)
        }
    }
}
