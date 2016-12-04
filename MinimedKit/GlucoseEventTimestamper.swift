//
//  GlucoseEventTimestamper.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 12/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class GlucoseEventTimestamper {

    public class func addTimestampsToEvents(events: [GlucoseEvent]) -> (processedEvents: [GlucoseEvent], unprocessedEvents: [GlucoseEvent]) {
        var processedEvents: [GlucoseEvent] = []
        var unprocessedEvents: [GlucoseEvent] = []
        
        for event in events.reversed() {
            if let referenceEvent = event as? ReferenceTimestampedGlucoseEvent {
                let relativeEventsWithTimestamp = timestampWithOffset(referenceTimestamp: referenceEvent.timestamp, unprocessedEvents: unprocessedEvents)
                processedEvents.append(referenceEvent)
                processedEvents.append(contentsOf: relativeEventsWithTimestamp)
                unprocessedEvents.removeAll()
            } else {
                unprocessedEvents.insert(event, at: 0)
            }
        }
        return (processedEvents: processedEvents, unprocessedEvents: unprocessedEvents)
    }
    
    class func timestampWithOffset(referenceTimestamp: DateComponents, unprocessedEvents: [GlucoseEvent]) -> [GlucoseEvent] {
        var eventsWithTimestamps = [GlucoseEvent]()
        let calendar = Calendar.current
        var date: Date = calendar.date(from: referenceTimestamp)!
        for event in unprocessedEvents {
            if var relativeEvent = event as? RelativeTimestampedGlucoseEvent {
                if !(relativeEvent is NineteenSomethingGlucoseEvent) {
                    date = calendar.date(byAdding: Calendar.Component.minute, value: 5, to: date)!
                }
                relativeEvent.timestamp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                relativeEvent.timestamp.calendar = calendar
                eventsWithTimestamps.append(relativeEvent)
            } else {
                eventsWithTimestamps.append(event)
            }
            
        }
        return eventsWithTimestamps
    }
}
