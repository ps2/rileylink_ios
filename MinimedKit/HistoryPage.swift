//
//  HistoryPage.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

public class HistoryPage {
    
    public enum Error: ErrorType {
        case InvalidCRC
        case UnknownEventType(eventType: UInt8)
    }
    
    public let events: [PumpEvent]
    
    public init(pageData: NSData, pumpModel: PumpModel) throws {
        
        guard checkCRC16(pageData) else {
            events = [PumpEvent]()
            throw Error.InvalidCRC
        }
        
        let pageData = pageData.subdataWithRange(NSMakeRange(0, 1022))
        
        func matchEvent(offset: Int) -> PumpEvent? {
            if let eventType = PumpEventType(rawValue:(pageData[offset] as UInt8)) {
                let remainingData = pageData.subdataWithRange(NSMakeRange(offset, pageData.length - offset))
                if let event = eventType.eventType.init(availableData: remainingData, pumpModel: pumpModel) {
                    return event
                }
            }
            return nil
        }
        
        var offset = 0
        let length = pageData.length
        var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
        var tempEvents = [PumpEvent]()
        
        while offset < length {
            // Slurp up 0's
            if pageData[offset] as UInt8 == 0 {
                offset += 1
                continue
            }
            guard var event = matchEvent(offset) else {
                events = [PumpEvent]()
                throw Error.UnknownEventType(eventType: pageData[offset] as UInt8)
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