//
//  GlucosePage.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/16/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class GlucosePage {
    
    public enum GlucosePageError: Error {
        case invalidCRC
        case unknownEventType(eventType: UInt8)
    }
    
    public let events: [GlucoseEvent]
    
    public init(pageData: Data, pumpModel: PumpModel) throws {
        
        guard checkCRC16(pageData) else {
            events = [GlucoseEvent]()
            throw GlucosePageError.invalidCRC
        }
        
        events = [GlucoseEvent]()
    }
}
