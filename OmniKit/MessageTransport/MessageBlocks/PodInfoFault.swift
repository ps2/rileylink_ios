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
    public var podInfoType              : PodInfoResponseSubType = .fault
    public let faultEventType           : PodInfoResponseSubType.FaultEventType
    public let timeActivation           : TimeInterval
    public let dateTime                 : DateComponents
    public let data                     : Data
    
    public init(encodedData: Data) throws {
        
        if encodedData.count < Int(16) {
            throw MessageBlockError.notEnoughData
        }
        
        self.faultEventType  = PodInfoResponseSubType.FaultEventType(rawValue: encodedData[1])!
        self.timeActivation  = TimeInterval(minutes: Double((Int(encodedData[2] & 0b1) << 8) + Int(encodedData[3])))
        self.dateTime        = DateComponents(encodedDateTime: encodedData.subdata(in: 12..<17))
        self.data            = Data(encodedData)
    }
}
