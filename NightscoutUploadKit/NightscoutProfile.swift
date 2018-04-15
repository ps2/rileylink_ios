//
//  NightscoutProfile.swift
//  NightscoutUploadKit
//

import Foundation

public class ProfileSet {
    
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
    
    public struct Profile {
        let timezone : TimeZone
        let dia : TimeInterval
        let sensitivity : [ScheduleItem]
        let carbratio : [ScheduleItem]
        let basal : [ScheduleItem]
        let targetLow : [ScheduleItem]
        let targetHigh : [ScheduleItem]
        let units: String
        
        public init(timezone: TimeZone, dia: TimeInterval, sensitivity: [ScheduleItem], carbratio: [ScheduleItem], basal: [ScheduleItem], targetLow: [ScheduleItem], targetHigh: [ScheduleItem], units: String) {
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
            return [
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
        }

    }
    
    let startDate : Date
    let units: String
    let enteredBy: String
    let defaultProfile: String
    let store: [String: Profile]
    
    public init(startDate: Date, units: String, enteredBy: String, defaultProfile: String, store: [String: Profile]) {
        self.startDate = startDate
        self.units = units
        self.enteredBy = enteredBy
        self.defaultProfile = defaultProfile
        self.store = store
    }
    
    public var dictionaryRepresentation: [String: Any] {
        let dateFormatter = DateFormatter.ISO8601DateFormatter()
        let mills = String(format: "%.0f", startDate.timeIntervalSince1970.milliseconds)
        
        let dictProfiles = Dictionary(uniqueKeysWithValues:
            store.map { key, value in (key, value.dictionaryRepresentation) })
        
        let rval : [String: Any] = [
            "defaultProfile": defaultProfile,
            "startDate": dateFormatter.string(from: startDate),
            "mills": mills,
            "units": units,
            "enteredBy": enteredBy,
            "store": dictProfiles
        ]
        
        return rval
    }
}
