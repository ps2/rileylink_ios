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
        var index = 0
        let beginPattern: [UInt8] = [0,0,0]
        let endPattern: [UInt8] = [0,0,0x3F]
        var basalSettings = [BasalScheduleData]()

        while (index * 3 + 3 < data.count) {
            let beginOfRange = index*3+1
            let endOfRange = beginOfRange+2
            
            if endOfRange >= data.count-1 {
                break
            }
            
            let section = Array(data[beginOfRange...endOfRange])
            
            // sanity check
            if index > 0 && (section == beginPattern ||
                section == endPattern) {
                break
            }
            
            let rateValue = section[0]
            let minutesValue = section[2]
            
            let rate = Double(rateValue) * 0.025
            let minutes = UInt(minutesValue) * 30
            
            let newBasalScheduleData = BasalScheduleData(index: index, minutes: minutes, rate: rate)
            basalSettings.append(newBasalScheduleData)
            
            index = index+1
        }
        
        return basalSettings
    }
}
