//
//  DeviceStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct DeviceStatus {
    let device: String
    let timestamp: NSDate
    let pumpStatus: PumpStatus?
    let uploaderStatus: UploaderStatus?
    let loopStatus: LoopStatus?
    
    public init(device: String, timestamp: NSDate, pumpStatus: PumpStatus? = nil, uploaderStatus: UploaderStatus? = nil, loopStatus: LoopStatus? = nil) {
        self.device = device
        self.timestamp = timestamp
        self.pumpStatus = pumpStatus
        self.uploaderStatus = uploaderStatus
        self.loopStatus = loopStatus
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

