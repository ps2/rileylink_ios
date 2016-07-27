//
//  DeviceStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class DeviceStatus {
    var loopStatus: LoopStatus? = nil
    var uploaderStatus: UploaderStatus? = nil
    var pumpStatus: PumpStatus? = nil
    let device: String
    
    init(device: String) {
        self.device = device
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        var rval = [String: AnyObject]()
        
        rval["device"] = device
        
        if let pump = pumpStatus {
            rval["pump"] = pump
        }
        
        if let uploader = uploaderStatus {
            rval["uploader"] = uploader
        }
        
        if let loop = loopStatus {
            rval["loop"] = loop
        }
        
        return rval
    }
}

