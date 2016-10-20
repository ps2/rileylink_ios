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
        
        //glucose page parsing happens in reverse byte order
        let pageData = pageData.subdata(in: 0..<1022).reverseBytes()
        
        var offset = 0
        let length = pageData.count
        var tempEvents = [GlucoseEvent]()
        var eventsNeedingTimestamp = [RelativeTimestampedGlucoseEvent]()
        
        func matchEvent(_ offset: Int) -> GlucoseEvent {
            let remainingData = pageData.subdata(in: offset..<pageData.count)
            let opcode = pageData[offset] as UInt8
            if let eventType = GlucoseEventType(rawValue: opcode) {
                if let event = eventType.eventType.init(availableData: remainingData, pumpModel: pumpModel) {
                    return event
                }
            }
            
            if opcode >= 20 {
                return GlucoseSensorDataGlucoseEvent(availableData: remainingData, pumpModel: pumpModel)!
            }
            
            return UnknownGlucoseEvent(availableData: remainingData, pumpModel: pumpModel)!
        }
        
        func addTimestampsToEvents(startTimestamp: DateComponents, eventsNeedingTimestamp: [RelativeTimestampedGlucoseEvent]) -> [GlucoseEvent] {
            var eventsWithTimestamps = [GlucoseEvent]()
            let calendar = Calendar.current
            var date : Date = calendar.date(from: startTimestamp)!
            for var event in eventsNeedingTimestamp {
                date = calendar.date(byAdding: Calendar.Component.minute, value: 5, to: date)!
                event.timestamp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                event.timestamp.calendar = calendar
                eventsWithTimestamps.append(event)
            }
            return eventsWithTimestamps
        }
        
        while offset < length {
            // Slurp up 0's
            if pageData[offset] as UInt8 == 0 {
                offset += 1
                continue
            }
            
            let event = matchEvent(offset)
            
            if let event = event as? RelativeTimestampedGlucoseEvent {
                eventsNeedingTimestamp.insert(event, at: 0)
            } else if let event = event as? ReferenceTimestampedGlucoseEvent {
                let eventsWithTimestamp = addTimestampsToEvents(startTimestamp: event.timestamp, eventsNeedingTimestamp: eventsNeedingTimestamp).reversed()
                tempEvents.append(contentsOf: eventsWithTimestamp)
                eventsNeedingTimestamp.removeAll()
                tempEvents.append(event)
            } else {
                tempEvents.append(event)
            }
            
            offset += event.length
        }
        events = tempEvents.reversed()
    }
}
