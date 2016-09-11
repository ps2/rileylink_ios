//
//  NSData.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 9/2/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension Data {
    /*@nonobjc subscript(index: Int) -> Int8 {
     let bytes: [Int8] = self[index...index]

     return bytes[0]
     }

     @nonobjc subscript(index: Int) -> UInt8 {
     let bytes: [UInt8] = self[index...index]

     return bytes[0]
     }
     */
    @nonobjc subscript(range: Range<Int>) -> UInt16 {
        var dataArray: UInt16 = 0
        let buffer = UnsafeMutableBufferPointer(start: &dataArray, count: range.count)
        _ = self.copyBytes(to: buffer, from: range)

        return dataArray
    }

    @nonobjc subscript(range: Range<Int>) -> UInt32 {
        var dataArray: UInt32 = 0
        let buffer = UnsafeMutableBufferPointer(start: &dataArray, count: range.count)
        _ = self.copyBytes(to: buffer, from: range)

        return dataArray
    }
    /*
     subscript(range: Range<Int>) -> [Int8] {
     var dataArray = [Int8](repeating: 0, count: range.count)
     let buffer = UnsafeMutableBufferPointer(start: &dataArray, count: range.count)
     _ = self.copyBytes(to: buffer, from: range)

     return dataArray
     }

     subscript(range: Range<Int>) -> [UInt8] {
     var dataArray = [UInt8](repeating: 0, count: range.count)
     self.copyBytes(to: &dataArray, from: range)

     return dataArray
     }

     subscript(range: Range<Int>) -> [UInt16] {
     var dataArray = [UInt16](repeating: 0, count: range.count / 2)
     let buffer = UnsafeMutableBufferPointer(start: &dataArray, count: range.count)
     _ = self.copyBytes(to: buffer, from: range)

     return dataArray
     }

     subscript(range: Range<Int>) -> [UInt32] {
     var dataArray = [UInt32](repeating: 0, count: range.count / 4)
     let buffer = UnsafeMutableBufferPointer(start: &dataArray, count: range.count)
     _ = self.copyBytes(to: buffer, from: range)

     return dataArray
     }
     */
}


extension Data {
    init?(hexadecimalString: String) {
        guard let chars = hexadecimalString.cString(using: String.Encoding.utf8) else {
            return nil
        }

        self.init(capacity: chars.count / 2)

        for i in 0..<chars.count / 2 {
            var num: UInt8 = 0
            var multi: UInt8 = 16

            for j in 0..<2 {
                let c = chars[i * 2 + j]
                var offset: UInt8

                switch c {
                case 48...57:   // '0'-'9'
                    offset = 48
                case 65...70:   // 'A'-'F'
                    offset = 65 - 10         // 10 since 'A' is 10, not 0
                case 97...102:  // 'a'-'f'
                    offset = 97 - 10         // 10 since 'a' is 10, not 0
                default:
                    return nil
                }

                num += (UInt8(c) - offset) * multi
                multi = 1
            }
            append(num)
        }
    }

    var hexadecimalString: String {
        let string = NSMutableString(capacity: count * 2)

        for byte in self {
            string.appendFormat("%02x", byte)
        }
        
        return string as String
    }
}
