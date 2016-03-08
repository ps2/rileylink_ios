//
//  HistoryPage.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

@objc public class HistoryPageTemp : NSObject {
  
  let pageData: NSData
  let pumpModel: PumpModel
  
  @objc public init?(pageData: NSData, pumpModel: PumpModel) {
    self.pageData = pageData
    self.pumpModel = pumpModel
  }
  
  @objc public func crcOK() -> Bool {
    let lowByte: UInt8 = pageData[pageData.length - 1]
    let hiByte: UInt8 = pageData[pageData.length - 2]
    let packetCRC: UInt16 =  (UInt16(hiByte) << 8) + UInt16(lowByte)
    return packetCRC == computeCRC16(pageData.subdataWithRange(NSMakeRange(0, pageData.length-2)))
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
  
  func decode() -> [PumpEvent] {
    var events = [PumpEvent]()
    var offset = 0
    let length = pageData.length
    var unabsorbedInsulinRecord: UnabsorbedInsulinPumpEvent?
    
    while offset < length {
      if let event = matchEvent(offset) {
        if event.dynamicType == BolusNormalPumpEvent.self && unabsorbedInsulinRecord != nil {
          let bolus: BolusNormalPumpEvent = event as! BolusNormalPumpEvent
          bolus.unabsorbedInsulinRecord = unabsorbedInsulinRecord
          unabsorbedInsulinRecord = nil
        }
        if event.dynamicType == UnabsorbedInsulinPumpEvent.self {
          unabsorbedInsulinRecord = event as? UnabsorbedInsulinPumpEvent
        } else {
          events.append(event)
        }
        offset += event.length
      } else {
        // TODO: Track bytes we skipped over
        offset += 1;
      }
    }
    return events
  }
}