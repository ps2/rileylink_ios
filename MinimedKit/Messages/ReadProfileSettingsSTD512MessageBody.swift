//
//  ReadProfileSettingsSTD512MessageBody.swift
//  RileyLink
//
//  Created by Jaim Zuber on 4/26/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BasalScheduleData {
    let index: Int
    let minutes: UInt
    let rate: Double
}

public class ReadProfileSettingsSTD512MessageBody : CarelinkLongMessageBody {

    public let basalSchedule: [BasalScheduleData]
    
    // implemented from https://github.com/bewest/decoding-carelink/blob/master/decocare/commands.py#L1080
    public required convenience init?(rxData: Data) {
        let theBasalSchedule = ReadProfileSettingsSTD512MessageBody.decodePumpSettings(data: rxData)
        
        self.init(basalSchedule: theBasalSchedule, rxData: rxData)
    }
    
    init?(basalSchedule: [BasalScheduleData], rxData: Data) {
        self.basalSchedule = basalSchedule
        super.init(rxData: rxData)
    }
    
    static private func decodePumpSettings(data: Data) -> [BasalScheduleData] {
        let beginPattern: [UInt8] = [0,0,0]
        let endPattern: [UInt8] = [0,0,0x3F]
        var basalSettings = [BasalScheduleData]()

        for tuple in sequence(first: (index:0, offset:1), next: { (index: $0.index+1, $0.offset + 3) }) {
            let beginOfRange = tuple.offset
            let endOfRange = beginOfRange+2
            
            if endOfRange >= data.count-1 {
                break
            }
            
            let section = Array(data[beginOfRange...endOfRange])
            
            // sanity check
            if tuple.index > 0 && (section == beginPattern ||
                section == endPattern) {
                break
            }
            
            let rateValue = section[0]
            let minutesValue = section[2]
            
            let rate = Double(rateValue) * 0.025
            let minutes = UInt(minutesValue) * 30
            
            let newBasalScheduleData = BasalScheduleData(index: tuple.index, minutes: minutes, rate: rate)
            basalSettings.append(newBasalScheduleData)
        }
        
        return basalSettings
    }
}
