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
    public let needsTimestamp: Bool
    
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
        let calendar = Calendar.current
        
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
        
        
        while offset < length {
            // ignore null bytes
            if pageData[offset] as UInt8 == 0 {
                offset += 1
                continue
            } else {
                break
            }
        }
        
        func initialTimestamp() -> DateComponents? {
            var tempOffset = offset
            var relativeEventCount = 0
            while tempOffset < length {
                let event = matchEvent(tempOffset, relativeTimestamp: DateComponents())
                if event is RelativeTimestampedGlucoseEvent {
                    relativeEventCount += 1
                } else if let sensorTimestampEvent = event as? SensorTimestampGlucoseEvent,
                    relativeEventCount == 0 || (event as! SensorTimestampGlucoseEvent).isForwardOffsetReference() {
                    
                    let offsetDate = calendar.date(byAdding: Calendar.Component.minute, value: 5 * relativeEventCount, to: sensorTimestampEvent.timestamp.date!)!
                    var relativeTimestamp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: offsetDate)
                    relativeTimestamp.calendar = calendar
                    return relativeTimestamp
                } else if !(event is NineteenSomethingGlucoseEvent /* seems to be a filler byte */ || event is DataEndGlucoseEvent) {
                    return nil
                }
                tempOffset += event.length
            }
            return nil
        }
        
        
        guard var relativeTimestamp = initialTimestamp() else {
            self.needsTimestamp = true
            self.events = events
            return
        }
        
        while offset < length {
            // ignore null bytes
            if pageData[offset] as UInt8 == 0 {
                offset += 1
                continue
            }
            
            let event = matchEvent(offset, relativeTimestamp: relativeTimestamp)
            if let event = event as? SensorTimestampGlucoseEvent {
                relativeTimestamp = event.timestamp
            } else if event is RelativeTimestampedGlucoseEvent {
                let offsetDate = calendar.date(byAdding: Calendar.Component.minute, value: -5, to: relativeTimestamp.date!)!
                relativeTimestamp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: offsetDate)
                relativeTimestamp.calendar = calendar
            }
            
            events.insert(event, at: 0)
            
            offset += event.length
        }
        self.needsTimestamp = false
        self.events = events
    }
}
