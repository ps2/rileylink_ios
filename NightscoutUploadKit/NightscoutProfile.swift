//
//  NightscoutProfile.swift
//  NightscoutUploadKit
//

import Foundation

public class NightscoutProfile {
    
    public struct ScheduleItem {
        let offset: TimeInterval
        let value: Double
        
        public init(offset: TimeInterval, value: Double) {
            self.offset = offset
            self.value = value
        }
        
        public var dictionaryRepresentation: [String: Any] {
            var rep = [String: Any]()
            let hours = floor(offset.hours)
            let minutes = floor((offset - TimeInterval(hours: hours)).minutes)
            rep["time"] = String(format:"%02i:%02i", Int(hours), Int(minutes))
            rep["value"] = value
            rep["timeAsSeconds"] = Int(offset)
            return rep
        }
    }
    
    let startDate : Date
    let name : String
    let timezone : TimeZone
    let dia : TimeInterval
    let sensitivity : [ScheduleItem]
    let carbratio : [ScheduleItem]
    let basal : [ScheduleItem]
    let targetLow : [ScheduleItem]
    let targetHigh : [ScheduleItem]
    let units: String
    
    public init(startDate: Date, name: String, timezone: TimeZone, dia: TimeInterval, sensitivity: [ScheduleItem], carbratio: [ScheduleItem], basal: [ScheduleItem], targetLow: [ScheduleItem], targetHigh: [ScheduleItem], units: String) {
        self.startDate = startDate
        self.name = name
        self.timezone = timezone
        self.dia = dia
        self.sensitivity = sensitivity
        self.carbratio = carbratio
        self.basal = basal
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.units = units
    }
    
    public var dictionaryRepresentation: [String: Any] {
        let dateFormatter = DateFormatter.ISO8601DateFormatter()
        
        let profile : [String: Any] = [
            "dia": dia.hours,
            "carbs_hr": "0",
            "delay": "0",
            "timezone": timezone.identifier,
            "target_low": targetLow.map { $0.dictionaryRepresentation },
            "target_high": targetHigh.map { $0.dictionaryRepresentation },
            "sens": sensitivity.map { $0.dictionaryRepresentation },
            "basal": basal.map { $0.dictionaryRepresentation },
            "carbratio": carbratio.map { $0.dictionaryRepresentation },
        ]
        
        
        let store : [String: Any] = [
            name: profile
        ]
        
        let rval : [String: Any] = [
            "defaultProfile": name,
            "startDate": dateFormatter.string(from: startDate),
            "mills": "0",
            "units": units,
            "enteredBy": "Loop",
            "store": store
        ]
        
        return rval
    }
}
