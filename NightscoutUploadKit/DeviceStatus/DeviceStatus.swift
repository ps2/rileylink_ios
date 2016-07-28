//
//  DeviceStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class DeviceStatus {
    public var loopStatus: LoopStatus? = nil
    public var uploaderStatus: UploaderStatus? = nil
    public var pumpStatus: PumpStatus? = nil
    public let device: String
    public let timestamp: NSDate
    
    public init(device: String, timestamp: NSDate) {
        self.device = device
        self.timestamp = timestamp
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["device"] = device
        rval["created_at"] = TimeFormat.timestampStrFromDate(timestamp)
        
        if let pump = pumpStatus {
            rval["pump"] = pump.dictionaryRepresentation
        }
        
        if let uploader = uploaderStatus {
            rval["uploader"] = uploader.dictionaryRepresentation
        }
        
        if let loop = loopStatus {
            rval["loop"] = loop.dictionaryRepresentation
        }
        
        return rval
    }
}

