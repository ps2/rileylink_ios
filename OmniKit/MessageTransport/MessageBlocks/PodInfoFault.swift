//
//  PodInfoFault.swift
//  OmniKit
//
//  Created by Eelke Jager on 25/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PodInfoFault : PodInfo {
    // https://github.com/openaps/openomni/wiki/Command-02-Status-Error-response
    public var blockType                : MessageBlockType = .podInfoResponse
    public let length                   : UInt8
    public var podInfoType              : PodInfoResponseSubType = .fault
    public let faultEventType           : PodInfoResponseSubType.FaultEventType
    public let timeActivation           : TimeInterval
    public let dateTime                 : DateComponents
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(16) {
            throw MessageBlockError.notEnoughData
        }
        
        self.length          = encodedData[1]
        self.faultEventType  = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[3])!
        self.timeActivation  = TimeInterval(minutes: Double((Int(encodedData[4] & 0b1) << 8) + Int(encodedData[5])))
        self.dateTime        = DateComponents(encodedDateTime: encodedData.subdata(in: 14..<19))
        //self.day            = encodedData[15]
        //self.year           = encodedData[16]
        //self.hour           = encodedData[17]
        //self.minute         = encodedData[18]
        //DateComponents(encodedData: encodedData[13...17])
        self.data = Data(encodedData)
    }
}
