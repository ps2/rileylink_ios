//
//  NSUserDefaults.swift
//  RileyLink
//
//  Created by Pete Schwamb on 6/23/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation


extension NSUserDefaults {
    private enum Key: String {
        case LastStoredTreatmentTimestamp = "com.rileylink.NightscoutUploadKit.LastStoredTreatmentTimestamp"
    }
    
    var lastStoredTreatmentTimestamp: NSDate? {
        get {
            return objectForKey(Key.LastStoredTreatmentTimestamp.rawValue) as? NSDate
        }
        set {
            setObject(newValue, forKey: Key.LastStoredTreatmentTimestamp.rawValue)
        }
    }
}