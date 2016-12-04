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
    
    public init(pageData: Data) throws {
        
        guard checkCRC16(pageData) else {
            events = [GlucoseEvent]()
            throw GlucosePageError.invalidCRC
        }
        
        //glucose page parsing happens in reverse byte order because
        //opcodes are at the end of each event
        let pageData = Data(pageData.subdata(in: 0..<1022).reversed())
        
        var offset = 0
        let length = pageData.count
        var tempEvents = [GlucoseEvent]()
        
        func matchEvent(_ offset: Int) -> GlucoseEvent {
            let remainingData = pageData.subdata(in: offset..<pageData.count)
            let opcode = pageData[offset] as UInt8
            if let eventType = GlucoseEventType(rawValue: opcode) {
                if let event = eventType.eventType.init(availableData: remainingData) {
                    return event
                }
            }
            
            if opcode >= 20 {
                return GlucoseSensorDataGlucoseEvent(availableData: remainingData)!
            }
            
            return UnknownGlucoseEvent(availableData: remainingData)!
        }
        
        while offset < length {
            // ignore null bytes
            if pageData[offset] as UInt8 == 0 {
                offset += 1
                continue
            }
            
            let event = matchEvent(offset)
            tempEvents.insert(event, at: 0)
            
            offset += event.length
        }
        events = tempEvents
    }
}
