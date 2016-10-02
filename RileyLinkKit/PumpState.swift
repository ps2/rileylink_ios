//
//  PumpState.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit


public class PumpState {

    /// The key for a string value naming the object property whose value changed
    public static let PropertyKey = "com.rileylink.RileyLinkKit.PumpState.PropertyKey"

    /// The key for the previous value of the object property whose value changed.
    /// If the value type does not conform to AnyObject, a raw representation will be provided instead.
    public static let ValueChangeOldKey = "com.rileylink.RileyLinkKit.PumpState.ValueChangeOldKey"

    public let pumpID: String
        
    public var timeZone: TimeZone = TimeZone.currentFixed {
        didSet {
            postChangeNotificationForKey("timeZone", oldValue: oldValue)
        }
    }
    
    public var pumpRegion: PumpRegion {
        didSet {
            postChangeNotificationForKey("pumpRegion", oldValue: oldValue.rawValue)
        }
    }
    
    public var pumpModel: PumpModel? {
        didSet {
            postChangeNotificationForKey("pumpModel", oldValue: oldValue?.rawValue)
        }
    }
    
    public var lastHistoryDump: Date? {
        didSet {
            postChangeNotificationForKey("lastHistoryDump", oldValue: oldValue)
        }
    }
    
    public var awakeUntil: Date? {
        didSet {
            postChangeNotificationForKey("awakeUntil", oldValue: awakeUntil)
        }
    }
    
    public init(pumpID: String, pumpRegion: PumpRegion) {
        self.pumpID = pumpID
        self.pumpRegion = pumpRegion
    }
    
    public var isAwake: Bool {
        if let awakeUntil = awakeUntil {
            return awakeUntil.timeIntervalSinceNow > 0
        }

        return false
    }
    
    public var lastWakeAttempt: Date?
    
    private func postChangeNotificationForKey(_ key: String, oldValue: Any?)  {
        var userInfo: [String: Any] = [
            type(of: self).PropertyKey: key
        ]
        
        if let oldValue = oldValue {
            userInfo[type(of: self).ValueChangeOldKey] = oldValue
        }
        
        NotificationCenter.default.post(name: .PumpStateValuesDidChange,
                                                                  object: self,
                                                                  userInfo: userInfo
        )
    }
}


extension PumpState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## PumpState",
            "timeZone: \(timeZone)",
            "pumpRegion: \(pumpRegion)",
            "pumpModel: \(pumpModel?.rawValue ?? "")",
            "lastHistoryDump: \(lastHistoryDump ?? .distantPast)",
            "awakeUntil: \(awakeUntil ?? .distantPast)",
            "lastWakeAttempt: \(lastWakeAttempt)",
        ].joined(separator: "\n")
    }
}


extension Notification.Name {
    /// Posted when values of the properties of the PumpState object have changed.
    /// The `userInfo` dictionary contains the following keys: `PropertyKey` and `ValueChangeOldKey`
    public static let PumpStateValuesDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkKit.PumpState.ValuesDidChangeNotification")
}
