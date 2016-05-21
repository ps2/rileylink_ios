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
    
    /// Posted when values of the properties of the PumpState object have changed.
    /// The `userInfo` dictionary contains the following keys: `PropertyKey` and `ValueChangeOldKey`
    public static let ValuesDidChangeNotification = "com.rileylink.RileyLinkKit.PumpState.ValuesDidChangeNotification"
    
    /// The key for a string value naming the object property whose value changed
    public static let PropertyKey = "com.rileylink.RileyLinkKit.PumpState.PropertyKey"
    
    /// The key for the previous value of the object property whose value changed.
    /// If the value type does not conform to AnyObject, a raw representation will be provided instead.
    public static let ValueChangeOldKey = "com.rileylink.RileyLinkKit.PumpState.ValueChangeOldKey"
    
    public let pumpID: String
    
    public var timeZone: NSTimeZone = NSTimeZone.defaultTimeZone() {
        didSet {
            postChangeNotificationForKey("timeZone", oldValue: oldValue)
        }
    }
    
    public var pumpModel: PumpModel? {
        didSet {
            postChangeNotificationForKey("pumpModel", oldValue: oldValue?.rawValue)
        }
    }
    
    public var lastHistoryDump: NSDate? {
        didSet {
            postChangeNotificationForKey("lastHistoryDump", oldValue: oldValue)
        }
    }
    
    public var awakeUntil: NSDate? {
        didSet {
            postChangeNotificationForKey("awakeUntil", oldValue: awakeUntil)
        }
    }
    
    public init(pumpID: String) {
        self.pumpID = pumpID
    }
    
    public var isAwake: Bool {
        return awakeUntil?.timeIntervalSinceNow > 0
    }
    
    private func postChangeNotificationForKey(key: String, oldValue: AnyObject?)  {
        var userInfo: [String: AnyObject] = [
            self.dynamicType.PropertyKey: key
        ]
        
        if let oldValue = oldValue {
            userInfo[self.dynamicType.ValueChangeOldKey] = oldValue
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ValuesDidChangeNotification,
                                                                  object: self,
                                                                  userInfo: userInfo
        )
    }
}
