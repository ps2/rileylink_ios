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
    public let timeOffset: TimeInterval
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
            
            let rate = Double((Int(section[1]) << 8) + Int(section[0])) * 0.025
            let timeOffset = TimeInterval(Int(section[2]) * 30 * 60)
            
            let newBasalScheduleEntry = BasalScheduleEntry(index: tuple.index, timeOffset: timeOffset, rate: rate)
            acc.append(newBasalScheduleEntry)
        }
        self.entries = acc
    }

}
