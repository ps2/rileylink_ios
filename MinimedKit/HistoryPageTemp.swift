//
//  HistoryPage.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/3/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

@objc public class HistoryPageTemp : NSObject {
  
  var pageData: NSData!
  
  @objc public init?(pageData: NSData) {
    self.pageData = pageData
  }
  
  @objc public func crcOK() -> Bool {
    //uint16_t packetCRC = bytes[_data.length-1] + (bytes[_data.length-2] << 8);
    //return packetCRC == [CRC16 compute:[_data subdataWithRange:NSMakeRange(0, _data.length-2)]];
    let lowByte: UInt8 = pageData[pageData.length - 1]
    let hiByte: UInt8 = pageData[pageData.length - 2]
    let packetCRC: UInt16 =  (UInt16(hiByte) << 16) + UInt16(lowByte)
    return packetCRC == computeCRC16(pageData)
  }
}