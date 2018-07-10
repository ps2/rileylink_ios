//
//  HistoryPage.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct HistoryPage {
    
    public enum HistoryPageError: Error {
        case invalidCRC
        case unknownEventType(eventType: UInt8)
    }
    
    public let events: [PumpEvent]

    // Useful interface for testing
    init(events: [PumpEvent]) {
        self.events = events
    }

    public init(pageData: Data, pumpModel: PumpModel) throws {
        
        guard checkCRC16(pageData) else {
            events = [PumpEvent]()
            throw HistoryPageError.invalidCRC
        }
        
        let pageData = pageData.subdata(in: 0..<1022)
        
        func matchEvent(_ offset: Int) -> PumpEvent? {
            if let eventType = PumpEventType(rawValue: pageData[offset]) {
                let remainingData = pageData.subdata(in: offset..<pageData.count)
                if let event = eventType.eventType.init(availableData: remainingData, pumpModel: pumpModel) {
                    return event
                }
            }
            return nil
        }
        
        var offset = 0
        let length = pageData.count
        var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
        var tempEvents = [PumpEvent]()
        
        while offset < length {
            // Slurp up 0's
            if pageData[offset] == 0 {
                offset += 1
                continue
            }
            guard var event = matchEvent(offset) else {
                events = [PumpEvent]()
                throw HistoryPageError.unknownEventType(eventType: pageData[offset])
            }

            if unabsorbedInsulinRecord != nil, var bolus = event as? BolusNormalPumpEvent {
                bolus.unabsorbedInsulinRecord = unabsorbedInsulinRecord
                unabsorbedInsulinRecord = nil
                event = bolus
            }
            if let event = event as? UnabsorbedInsulinPumpEvent {
                unabsorbedInsulinRecord = event
            } else {
                tempEvents.append(event)
            }
            offset += event.length
        }
        events = tempEvents
    }
}
