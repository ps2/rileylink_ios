//
//  UserDefaults.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit
import RileyLinkKit
import RileyLinkBLEKit

extension UserDefaults {
    private enum Key: String {
        case pumpManagerRawValue = "com.rileylink.PumpManagerRawValue"
        case rileyLinkConnectionManagerRawValue = "com.rileylink.RileyLinkConnectionManager"
    }
    
    var pumpManagerRawValue: PumpManager.RawStateValue? {
        get {
            return dictionary(forKey: Key.pumpManagerRawValue.rawValue)
        }
        set {
            set(newValue, forKey: Key.pumpManagerRawValue.rawValue)
        }
    }
    
    var rileyLinkConnectionManager: RileyLinkConnectionManager? {
        get {
            guard let rawValue = dictionary(forKey: Key.rileyLinkConnectionManagerRawValue.rawValue) else
            {
                return nil
            }
            return RileyLinkConnectionManager(rawValue: rawValue)
        }
        set {
            set(newValue?.rawState, forKey: Key.rileyLinkConnectionManagerRawValue.rawValue)
        }
    }

}

