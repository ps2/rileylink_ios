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
    
    func matchEvent(offset: Int) -> PumpEvent? {
      if let eventType = PumpEventType(rawValue:pageData[offset]) {
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
      guard let event = matchEvent(offset) else {
        events = [PumpEvent]()
        throw Error.UnknownEventType(eventType: pageData[offset] as UInt8)
      }
      if event.dynamicType == BolusNormalPumpEvent.self && unabsorbedInsulinRecord != nil {
        let bolus: BolusNormalPumpEvent = event as! BolusNormalPumpEvent
        bolus.unabsorbedInsulinRecord = unabsorbedInsulinRecord
        unabsorbedInsulinRecord = nil
      }
      if event.dynamicType == UnabsorbedInsulinPumpEvent.self {
        unabsorbedInsulinRecord = event as? UnabsorbedInsulinPumpEvent
      } else {
        tempEvents.append(event)
      }
      offset += event.length
    }
    events = tempEvents
  }
}