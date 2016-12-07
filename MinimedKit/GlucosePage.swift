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
            self.events = [GlucoseEvent]()
            throw GlucosePageError.invalidCRC
        }
        
        //glucose page parsing happens in reverse byte order because
        //opcodes are at the end of each event
        let pageData = Data(pageData.subdata(in: 0..<1022).reversed())
        
        var offset = 0
        let length = pageData.count
        var events = [GlucoseEvent]()
        
        func matchEvent(_ offset: Int, relativeTimestamp: DateComponents) -> GlucoseEvent {
            let remainingData = pageData.subdata(in: offset..<pageData.count)
            let opcode = pageData[offset] as UInt8
            if let eventType = GlucoseEventType(rawValue: opcode) {
                if let event = eventType.eventType.init(availableData: remainingData, relativeTimestamp: relativeTimestamp) {
                    return event
                }
            }
            
            if opcode >= 20 {
                return GlucoseSensorDataGlucoseEvent(availableData: remainingData, relativeTimestamp: relativeTimestamp)!
            }
            
            return UnknownGlucoseEvent(availableData: remainingData, relativeTimestamp: relativeTimestamp)!
        }
        
        let calendar = Calendar.current
        var relativeTimestamp: DateComponents = DateComponents()
        
        while offset < length {
            let event = matchEvent(offset, relativeTimestamp: relativeTimestamp)
            if let event = event as? ReferenceTimestampedGlucoseEvent {
                relativeTimestamp = event.timestamp
            } else if event is RelativeTimestampedGlucoseEvent && relativeTimestamp.date != nil {
                let offsetDate = calendar.date(byAdding: Calendar.Component.minute, value: -5, to: relativeTimestamp.date!)!
                relativeTimestamp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: offsetDate)
                relativeTimestamp.calendar = calendar
            }
            events.insert(event, at: 0)
            
            offset += event.length
        }
        self.events = events
    }
}
