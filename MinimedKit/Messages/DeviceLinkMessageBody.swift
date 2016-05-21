//
//  DeviceLinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct DeviceLinkMessageBody: MessageBody {
    
    public static let length = 5
    
    public let deviceAddress: NSData
    public let sequence: UInt8
    let rxData: NSData
    
    
    public init?(rxData: NSData) {
        self.rxData = rxData
        
        if rxData.length == self.dynamicType.length {
            self.deviceAddress = rxData.subdataWithRange(NSRange(1...3))
            sequence = rxData[0] & 0b1111111
        } else {
            return nil
        }
    }
    
    public var txData: NSData {
        return rxData
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "sequence": Int(sequence),
            "deviceAddress": deviceAddress.hexadecimalString,
        ]
    }
    
}
