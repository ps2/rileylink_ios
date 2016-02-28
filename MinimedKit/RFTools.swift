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
  let bytes: [UInt8] = rawData[0..<rawData.length]
  var availBits: UInt = 0
  var x: UInt = 0
  for byte in bytes {
    x = (x << 8) + UInt(byte)
    availBits += 8
    if availBits >= 12 {
      guard let
        hiNibble = codes[x >> (availBits - 6)],
        loNibble = codes[(x >> (availBits - 12)) & 0b111111]
        else {
        return nil
      }
      let decoded = UInt8((hiNibble << 4) + loNibble)
      buffer.append(decoded)
      availBits -= 12;
      x = x & (0xffff >> (16-availBits));
    }
  }
  return NSData(bytes: &buffer, length: buffer.count)
}

func encode4b6b(rawData: NSData) -> NSData {
  var buffer = [UInt8]()
  let codes: [Int] = [21,49,50,35,52,37,38,22,26,25,42,11,44,13,14,28]
  let bytes: [UInt8] = rawData[0..<rawData.length]
  var acc = 0x0
  var bitcount = 0
  for byte in bytes {
    acc <<= 6;
    acc |= codes[Int(byte >> 4)]
    bitcount += 6;
    
    acc <<= 6;
    acc |= codes[Int(byte & 0x0f)];
    bitcount += 6;
    
    while bitcount >= 8 {
      buffer.append(UInt8(acc >> (bitcount-8)) & 0xff)
      bitcount -= 8;
      acc &= (0xffff >> (16-bitcount));
    }
  }
  if bitcount > 0 {
    acc <<= (8-bitcount);
    buffer.append(UInt8(acc) & 0xff);
  }
  return NSData(bytes: &buffer, length: buffer.count)
}

