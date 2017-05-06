//
//  BasalSchedule.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/6/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalScheduleEntry {
    public let index: Int
    public let minutes: Int
    public let rate: Double
}


public struct BasalSchedule {
    public let entries: [BasalScheduleEntry]
 
    public init(data: Data) {
        let beginPattern: [UInt8] = [0,0,0]
        let endPattern: [UInt8] = [0,0,0x3F]
        var acc = [BasalScheduleEntry]()
        
        for tuple in sequence(first: (index:0, offset:0), next: { (index: $0.index+1, $0.offset + 3) }) {
            let beginOfRange = tuple.offset
            let endOfRange = beginOfRange+2
            
            if endOfRange >= data.count-1 {
                break
            }
            
            let section = Array(data[beginOfRange...endOfRange])
            
            // sanity check
            if (section == beginPattern || section == endPattern) {
                break
            }
            
            let rateValue = (Int(section[1]) << 8) + Int(section[0])
            let minutesValue = section[2]
            
            let rate = Double(rateValue) * 0.025
            let minutes = Int(minutesValue) * 30
            
            let newBasalScheduleEntry = BasalScheduleEntry(index: tuple.index, minutes: minutes, rate: rate)
            acc.append(newBasalScheduleEntry)
        }
        self.entries = acc
    }

}
