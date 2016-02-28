//
//  RFTools.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

func decode4b6b(rawData: NSData) -> NSData? {
  let codes:Dictionary<UInt, UInt8> = [21: 0, 49: 1, 50: 2, 35: 3, 52: 4, 37: 5, 38: 6, 22: 7, 26: 8, 25: 9, 42: 10, 11: 11, 44: 12, 13: 13, 14: 14, 28: 15]
  var buffer = [UInt8]()
  let bytes = UnsafeBufferPointer<UInt8>(start:UnsafePointer<UInt8>(rawData.bytes), count:rawData.length)
  var availBits: UInt = 0
  var x: UInt = 0
  var hiNibble: UInt8?
  var loNibble: UInt8?
  for var i = 0; i < rawData.length; i++ {
    x = (x << 8) + UInt(bytes[i])
    availBits += 8
    if availBits >= 12 {
      hiNibble = codes[x >> (availBits - 6)]
      loNibble = codes[(x >> (availBits - 12)) & 0b111111]
      
      if hiNibble != nil && loNibble != nil {
        let decoded: UInt8 = UInt8((hiNibble! << 4) + loNibble!)
        buffer.append(decoded)
      } else {
        return nil
      }
      availBits -= 12;
      x = x & (0xffff >> (16-availBits));
    }
  }
  return NSData(bytes: &buffer, length: buffer.count)
}

func encode4b6b(rawData: NSData) -> NSData {
  var buffer = [UInt8]()
  let codes: [UInt] = [21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28]
  let bytes = UnsafeBufferPointer<UInt8>(start:UnsafePointer<UInt8>(rawData.bytes), count:rawData.length)
  var acc: UInt = 0x0
  var bitcount: UInt = 0
  for var i=0; i < rawData.length; i++ {
    acc <<= 6;
    acc |= codes[Int(bytes[i] >> 4)]
    bitcount += 6;
    
    acc <<= 6;
    acc |= codes[Int(bytes[i] & 0x0f)];
    bitcount += 6;
    
    while bitcount >= 8 {
      buffer.append(UInt8(acc >> (bitcount-8)) & 0xff)
      bitcount -= 8;
      acc &= (0xffff >> (16-bitcount));
    }
  }
  if (bitcount > 0) {
    acc <<= (8-bitcount);
    buffer.append(UInt8(acc) & 0xff);
  }
  return NSData(bytes: &buffer, length: buffer.count)
}

